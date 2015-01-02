require 'hiera/filecache'

class Hiera
  module Backend
    class Regex_backend

      # TODO: Support JSON or YAML format and initialize accordingly
      def initialize(cache=nil)
         require 'yaml'
         @cache = cache || Filecache.new
      end

      # TODO: Support multiple resolution_types, currently only supports :priority
      def lookup(key, scope, order_override, resolution_type)
         answer = nil
         datasourcefiles(scope) do |source|
           scope_key = File.basename(source, ".regex")
           scope_key = "::#{scope_key}" if ! scope[scope_key]
           if ! scope[scope_key]
             Hiera.debug("Could not find key #{scope_key} within scope, skipping check for source #{source}")
             next
           end
           Hiera.debug("Checking #{source} for #{scope_key} regex matching #{scope[scope_key]}")

           # TODO: Add support for more than just YAML format
           data = YAML.load(@cache.read(source))

           next if ! data
           next if data.empty?

           lineno = 0
           data.each do |item|
             lineno = lineno + 1
             item.each_key do |regex_key|
               if scope[scope_key] =~ /#{regex_key}/ and item[regex_key][key]
                 Hiera.debug("#{scope_key} with value of '#{scope[scope_key]}' matched regex /#{regex_key}/ at #{source}:#{lineno}")
                 new_answer = Backend.parse_answer(item[regex_key][key], scope)
                 case resolution_type
                 when :array
                   raise Exception, "Hiera type mismatch for key '#{key}': expected Array and got #{new_answer.class}" unless new_answer.kind_of? Array or new_answer.kind_of? String
                   answer ||= []
                   answer << new_answer
                 when :hash
                   raise Exception, "Hiera type mismatch for key '#{key}': expected Hash and got #{new_answer.class}" unless new_answer.kind_of? Hash
                   answer ||= {}
                   answer = Backend.merge_answer(new_answer,answer)
                 else
                   answer = new_answer
                   return answer
                 end
               end
             end
           end
         end
         return answer
       end

       def datasources(scope)
         datadir = Backend.datadir(:regex, scope)
         Config[:hierarchy].flatten.map do |source|
           # We only support data sources that end in a key.  Keys found
           # in the middle of a datasource's name are impossible to support since
           # standard file names do not do well containing regular experssion patterns
           if source =~ /\}$/
             # We need to strip out the ending key's %{::} characters so that they do not
             # get interpolated when we call parse_string
             yield(Backend.parse_string(source.gsub(/%\{:*([^\{]*)\}$/, '\1'), scope))
           end
         end
       end

       def datasourcefiles(scope)
         datadir = Backend.datadir(:regex, scope)
         datasources(scope) do |source|
           file = Backend.datafile(:regex, scope, source, :regex)
           if file
             yield(file)
           end
         end
       end
    end
  end
end
