# Hiera Regex
Hiera Regex matches client facts against a regex string to provide hierarchical data.  A typical use case would be matching against a hostname pattern rather than using the standard file backend where each FQDN would require it's own file.

## How it works
Hiera regex works very similar to the standard file backend with hiera with the exception of the filename used to lookup data.  The last key in a hierarchy is used as the filename with the .regex extension for lookups.  So if you wanted to do a regex on the `::fqdn` fact, your filename would be fqdn.regex.

The contents of the .regex file will be an array of hashes.  The purpose of the array is to provide an order in which you want the fqdn regex to be evaluated.  Each array element contains a hash which has a key that is the regex to be tested against the fqdn fact.  The value of the hash is a hash which contains the hiera key/value pairs that can be requested.

Let's walk through an example using the hierarchy and files below

/etc/puppet/hiera.yaml:
```
:backends:
  - regex
  - yaml
:yaml:
  :datadir: /var/lib/hiera
:regex:
  :datadir: /var/lib/hiera
:hierarchy:
  - "fqdn/%{::fqdn}"
  - common
```

/var/lib/hiera/fqdn/fqdn.regex:
```
---
 - '^mailin-trusted.example.org$':
     postfix::smtp_relay: 'mailout-dmz.example.org'
 - '^mailout.*':
     postfix::smtp_relay: 'smtp.mailgun.org'
 - '^mailin.*':
     postfix::smtp_relay: 'localhost'
```

/var/lib/hiera/common.yaml:
```
---
postfix::smtp_relay: 'mailin-trusted.example.org'
```

Now let's walk through a few values for `::fqdn`
`$::fqdn == 'mailout-dmz1.example.org'`: *Result:* smtp.mailgun.org

`$::fqdn == 'mailout-dmz1.example.org'`: smtp.mailgun.org

`$::fqdn == 'mailout-dmz2.example.org'`: smtp.mailgun.org

`$::fqdn == 'mailin-dmz1.example.org'`: localhost

`$::fqdn == 'mailin-dmz2.example.org'`: localhost

`$::fqdn == 'mailin-trusted.example.org'`: mailout-dmz.example.org

`$::fqdn == 'someserver.example.org'`: mailin-trusted.example.org


The time savings of using the regex backend is not having to create seperate YAML files for each mail(out|in)-dmz[1-2] server.  Adding a new outbound DMZ mail server requires no changes to the hiera data, and if the outbound mail relay needs to change from smtp.mailgun.org to smtp.gmail.com the change only needs to be made in once place.

Having multiple hiera lookup keys in your regex file would look like this:

/var/lib/hiera/fqdn/fqdn.regex:
```
---
 - '^mailout.*':
     postfix::smtp_relay: 'smtp.mailgun.org'
     postfix::mynetworks: '10.12.1.0/24,127.0.0.1'
 - '^mailin.*':
     postfix::smtp_relay: 'localhost'
     postfix::mynetworks: '10.0.0.0/8,127.0.0.1'
```

##Gotchas
When intermingeling the regex and yaml backends your hierarchies will sometimes step on each other if you don't pay close attention to some of the nuiances between the two.

How you setup your key/value pairs depends on if you want the yaml backend to be before or after the regex backend in the hierarchy.

The recommended method would be to have the regex backend first and the yaml backend second.  This is because there are some limitations to default fallthru values (i.e. common.yaml) when putting the yaml backend first.  Those are discussed in more detail in the second example.

###Example 1 - Regex backend first in the hierarchy (Recommended)
/etc/puppet/hiera.conf
```
:backends:
  - regex
  - yaml
:yaml:
  :datadir: /var/lib/hiera
:regex:
  :datadir: /var/lib/hiera
:hierarchy:
  - "fqdn/%{::fqdn}"
  - common
```
The common gotcha with this configuration is continuing to rely on the fqdn.yaml files when fqdn might match a regex. In the how-to example you saw that the fqdn `mailin-trusted.example.org` had a directly match value for the key `postfix::smtp_relay`.  Here's the regex file so you don't have to scroll back up.
/var/lib/hiera/fqdn/fqdn.regex:
```
---
 - '^mailin-trusted.example.org$':
     postfix::smtp_relay: 'mailout-dmz.example.org'
 - '^mailout.*':
     postfix::smtp_relay: 'smtp.mailgun.org'
 - '^mailin.*':
     postfix::smtp_relay: 'localhost'
```
With the yaml backend this would normally be achieved by creating a file `fqdn/mailin-trusted.example.org.yaml`.  If the direct matched regex were not in the fqdn.regex file and you were relying on the yaml backend to find the value in `fqdn/mailin-trusted.example.org.yaml`, this would never be evaluated because the fqdn `mailin-trusted.example.org` matches the regex `^mailin.*'.  So the value would have been `localhost` instead of `mailout-dmz.example.org`.

So to summarize, you can continue to use fact.yaml files as long as you don't use the regex backend for that particular fact.  If you do use the regex for a fact, your default values in common.yaml will still work, assuming you don't match on `/.*/`.

##Example 2 - Regex backend after yaml backend in hierarchy (Has limitiations)
The common gotcha with this approach is having key/value pair in common.yaml which causes your regex backend to never get evaluted.  You can still have default values, they just need to be the last matching key of the regex backend.
/var/lib/hiera/fqnd/fqdn.regex:
```
---
 - '^mailout.*':
     postfix::smtp_relay: 'smtp.mailgun.org'
 - '^mailin.*':
     postfix::smtp_relay: 'localhost'
 - '.*':
     postfix::smtp_relay: 'mailin-trusted.example.org'
```
Here the default value for no matching yaml backend files and no matching regex keys is `mailin-trusted.example.org` since `.*` matches anything.

There is a limitation to this approach.  Your default will sometimes get matched even when there is still a regex yet to be evaluated lower in the hierarchy.  For example, if your hierarchy was:
```
:hierarchy
 - fqdn/%{::fqdn}
 - network/%{::network_eth0}
 - common
```
and your network_eth0 fact were to match a regex, it would never get evaluated if you used the /.*/ default match in fqdn, since it is first in the hierarchy. This is why example 1 which puts the regex before the yaml backend is the recommended implementation.

