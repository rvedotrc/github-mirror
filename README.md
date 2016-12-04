github-mirror - read and scan commits from github
-------------------------------------------------

Use case: finding secrets (passwords, keys) that have been committed to
github, that so that those secrets can be revoked, and removed from git.

Initial setup
-------------

`  bundle install`  
`  mkdir etc var`  

Plus you'll need a github account; an ssh key (registered with that account)
to do the cloning; and a github API key (to list the repositories).

Create `./etc/github-mirror.json` like this:

`{`  
`  "github": {`  
`    "user": "your-github-username"`  
`    "pass": "your-github-secret"`  
`  }`  
`}`  

Running (first time, or thereafter)
-----------------------------------

```
    ./run
    ./bin/tried-keys-report
```

If you have many AWS accounts, you might want to use `./bin/which-accounts` to
cross-reference that data to your list of accounts.  (Requires list of
accounts in JSON format; exercise left for the reader).

TODO
----

 * Look for other kinds of secrets, e.g. passwords, API keys, RSA private keys
 * More automation; report more about where each secret was found.

