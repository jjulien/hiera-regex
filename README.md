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
 - '^mailout.*':
     postfix::smtp_relay: 'smtp.mailgun.org'
 - '^mailin.*':
     postfix::smtp_relay: 'localhost'
```

/var/lib/hiera/fqdn/mainout-trusted.example.org.yaml:
```
---
postfix::smtp_relay: 'mailout-dmz.example.org'
```

/var/lib/hiera/common.yaml:
```
postfix::smtp_relay: 'mailin-trusted.example.org'
```

Now let's walkthrough a few scenarios

`$::fqdn == 'mailout-dmz1.example.org'`: smtp.mailgun.org

`$::fqdn == 'mailout-dmz2.example.org'`: smtp.mailgun.org

`$::fqdn == 'mailin-dmz1.example.org'`: localhost

`$::fqdn == 'mailin-dmz2.example.org'`: localhost

`$::fqdn == 'mailin-trusted.example.org'`: mailout-dmz.example.org

`$::fqdn == 'someserver.example.org'`: mailin-trusted.example.org


The time savings of using the regex backend is not having to create seperate YAML files for each mail(out|in)-dmz[1-2] server.  Adding a new outbound DMZ mail server requires no changes to the hiera data, and if the outbound mail relay needs to change from smtp.mailgun.org to smtp.gmail.com the change only needs to be made in once place.

It is important to note that the regex backend has to come BEFORE the yaml backend in your hierarchy.  If it does not, then in the above example all of the DMZ servers would have ended up evaluating to the common.yaml by fallthru and no regex attempts would be made.

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
