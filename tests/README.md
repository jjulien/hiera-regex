## Testing
This directory is used to store test data, configs, and scopes for use during development.

To execute a test lookup you will need to prepend your local lib path to `RUBYLIB`, pass an optional scope in, and pass the key you want to lookup.

**Example**
```
export RUBYLIB=lib:$RUBYLIB
hiera -c tests/hiera.yaml -j tests/scopes/mailout.json postfix::smtp_relay
```
