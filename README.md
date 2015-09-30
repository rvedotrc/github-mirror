github-mirror - read and scan commits from github
-------------------------------------------------

Use case: finding secrets (passwords, keys) that have been committed to
github, that so that those secrets can be revoked, and removed from git.

Initial setup
-------------

`  bundle install`  
`  mkdir var`  

Plus you'll need a github account; an ssh key (registered with that account)
to do the cloning; and a github API key (to list the repositories).

Currently my username and organisations of interest are hard-wired in the
`clone-missing` script.  You'll need to edit those.

Running (first time, or thereafter)
-----------------------------------

Find what repositories there are, and when each one was last pushed to:

`  ./bin/list-repos > list-repos.json`  

Locally fetch all repositories and commits that we don't have yet:

`  ./bin/clone-missing`  

Scan all the commits we haven't scanned yet to find those which potentially
contain secrets:

`  ./bin/scan-commits`  

Analyse all the interesting commits found so far (note: not incremental):

`  ./bin/analyse-commits > commits-and-secrets.json`  
`  cat commits-and-secrets.json | jq -c '.old_permutations[], .new_permutations[]' | sort -u | jq --slurp . > keys-to-try.json`  

Try the keys to see which ones are good:

`  ./bin/try-keys < keys-to-try.json`  

TODO
----

 * Look for other kinds of secrets, e.g. passwords, API keys, RSA private keys
 * Closer analysis of the output of `scan-commits` to extract the secrets
   themselves.

