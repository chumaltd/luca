# Luca Salary

[![Gem Version](https://badge.fury.io/rb/lucasalary.svg)](https://badge.fury.io/rb/lucasalary)

LucaSalary is Abstraction framework coworking with each country module. As income tax differs in each county, most of implementation need to be developed separately.  
At this time, [Japan module](https://github.com/chumaltd/luca-salary-jp) is under development as a practical reference.

## Usage

Create blank profile of employees.

```
$ luca-salary profiles create EmployeeName
```

Profile is in YAML format. Need to describe along with each country requirement.  
Once profiles completed, monthly payment records can be generated as follows:

```
$ luca-salary payments create yyyy m
```

Report is available with generated data as follows:

```
$ luca-salary payments list [--mail] yyyy m
```
