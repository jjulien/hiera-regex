## Testing
This directory is used to store test data, configs, and scopres for use during development.

To execute a test lookup, from the root of the project directory run the `hiera`, an optional test scope, and the key you want to look up.

*Example*
```
hiera -c tests/hiera.yaml -j tests/scopes/mailout.json postfix::smtp_relay
```
