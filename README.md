
### Crazy Train Deploy Daemon
This is how you run this:

1. Make a config file `.config.yml`
2. Add the deploy directory to said file:

```
deploy_dir: /path/to/statics/directory
src_dir: /path/to/src/directory
hooks:
- owner/repo: event
- owner/another_repo: another_event
```
3. Profit $$$$

> Not finished yet
