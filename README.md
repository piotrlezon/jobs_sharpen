# Getting started

Clone the repo, make sure the dependencies are set up (mysql & ruby), run `bin/setup` & you're all set!
 
To follow the exercise, go with  `git checkout level-1` and `bundle exec guard`.

You'll see a set of specs that you have to make green (I encourage you to `git show HEAD` too!).

Once you've saved the day, run `git cherry-pick level-2` and then increment the level each time you make the specs pass.

You can always sneak on a sample solution with `git show level-1-solution` (look for TBH & TODO comments for questions
 worth giving some thought).

Enjoy!

# Contributing

QAD one liner to re-tag levels:

```
export STARTING_COMMIT=<hash of level-1 commit> ; git ls-remote --tags origin | awk '/^(.*)(\s+)(.*[a-z0-9])$/ {print ":" $2}' | xargs git push origin; git tag | xargs git tag -d; ruby -e 'system("git rebase -i #{ENV["STARTING_COMMIT"]}\^"); (0..(`git log #{ENV["STARTING_COMMIT"]}..master --pretty=oneline | wc -l`.to_i)).each { |i| system("git tag level-#{i/2 + 1 }#{"-solution" if i % 2 == 1}; git rebase --continue") }'
```
