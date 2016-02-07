# git-commits-analysis
Analyze your development phase by the commits done to git and their releted Jira issues.

This is an example of an output:

![alt tag](https://github.com/oridanus/git-commits-analysis/blob/master/example-results.png)

## The input 
can be one of the 2:

a Jira JQL, like:
```
         project = "MYPROJ" AND version = 1.0
```

OR

a CSV of the commits, produce by running:
```
         git log --grep whatever --no-merges --pretty=format:%an,%ai,%s,%h" > wherever.csv
```
## The Output
The tool produces an html output: 

1. Each row is a Jira issue - taken from the commit messages, followed by the issue summary.

2. Each column is a day in the period of time.

3. Each cell reprsents how many commits were done for this issue in this day

4. "Actual Total Days Worked On" - is the number of days which at least one commit was done for this issue

5. "Days Estimated" - is taken from the Jira issue "timeoriginalestimate" field

6. If "Actual Total Days Worked On" <= "Days Estimated" - both will be green, we made it on time! otherwise it's red.

