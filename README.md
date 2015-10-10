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

Find what repositories there are, and when each one was last pushed to:

`  ./bin/list-repos`  

Locally fetch all repositories and commits that we don't have yet:

`  ./bin/clone-missing`  

Scan all the commits we haven't scanned yet to find those which potentially
contain secrets:

`  ./bin/scan-commits`  

Analyse all the interesting commits found so far (note: not incremental):

`  ./bin/analyse-commits > var/commits-and-secrets.json`  
`  cat var/commits-and-secrets.json | jq -c '.old_permutations[], .new_permutations[]' | sort -u | jq --slurp . > var/keys-to-try.json`  
`  cat var/commits-and-secrets.json | jq --slurp . | ./bin/activity-log`  

Try the keys to see which ones are good:

`  ./bin/try-keys < var/keys-to-try.json`  

If you have many AWS accounts, you might want to use `./bin/which-accounts` to
cross-reference that data to your list of accounts.  (Requires list of
accounts in JSON format; exercise left for the reader).

TODO
----

 * Look for other kinds of secrets, e.g. passwords, API keys, RSA private keys
 * More automation; report more about where each secret was found.

Files
-----

A note on relevant files.

 * etc/github-mirror.json - configuration

 * var/list-repos.json - generated by list-repos, used by clone-repos

 * var/try-key.json - used by try-keys
 * var/aws-accounts.json - used by which-accounts

 * var/commits-and-secrets.json - ?
 * var/keys-to-try.json - ?

 * var/github/orgname/reponame/
 * * `mirror/` - mirror of the repository
 * * `pushed_at` - set and used by clone-repos
 * * `mirror-changed` - flag set by clone-repos, used by scan-commits
 * * `scanned-refs.json` - set and used by scan-commits
 * * `interesting.json` - set by scan-commits, used by analyse-commits
 * * `interesting-changed` - set by scan-commits (TODO, use by analyse-commits)

