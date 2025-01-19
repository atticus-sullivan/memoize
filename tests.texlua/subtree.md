# git subtree

Used instead of git submodule to include the lester testing framework.

With subtree not everything is perfect, but with submodule things are more
messy: https://blog.timhutt.co.uk/against-submodules/

## Usage
c.f. https://www.atlassian.com/git/tutorials/git-subtree

adding the repo

```
git remote add -f lester-upstream https://github.com/edubart/lester.git
git subtree add --prefix "tests.texlua/testing/lester" lester-upstream main --squash
```

update the subtree
```
git fetch lester-upstream main
git subtree pull --prefix "tests.texlua/testing/lester" lester-upstream main --squash
```

contribute back
1. fork the project and add it as new remote
push via
```
git subtree push --prefix "tests.texlua/testing/lester" lester-upstream main --squash
```
