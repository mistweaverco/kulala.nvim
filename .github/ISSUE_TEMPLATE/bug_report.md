---
name: Bug report
about: Create a report to help us improve
title: "[BUG] "
labels: bug
assignees: ''

---

The easiest way to submit a bug report is to set the option `generate_bug_report` in the config.

This will offer to generate a bug report and open a GitHub Issue with it, when an error is encountered. 

Alternatively, you can generate the report manually with `require("kulala").generate_bug_report()` or follow the template below.

#

**Describe the bug**
A clear and concise description of what the bug is.

**Check health**
Run `:checkhealth kualala` and paste the output here if there are any errors.

**Submit the error stacktrace**
Set `debug = true` in your Kulala config and submit the copy of the stacktrace.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Additional context**
Add any other context about the problem here.
