/*-------------------------------------------------------------------------------
# Name:		01_UGA_PHIA_analysis
# Purpose:	Create estimates for HIV prevalence by AGYW and Age
# Author:	Cody Adelson, MSc
# Created:	2020-01-31
# Owner:	USAID OHA
# License:	MIT License
# Ado(s):	see below
#-------------------------------------------------------------------------------
*/
ssc install tab3way  
ssc install confirmdir
clear

* Folder and path setup code 
* Determine path for the study
global projectpath "C:\Users\cadelson\Documents\Github"
cd "$projectpath"

* Run a macro to set up study folder
* Name the file path below -- replace nigerlsms with your folder name
local pFolder UgandaPHIA
foreach dir in `pFolder' {
	confirmdir "`dir'"
	if `r(confirmdir)'==170 {
		mkdir "`dir'"
		display in yellow "Project directory named: `dir' created"
		}
	else disp as error "`dir' already exists, not created."
	cd "$projectpath/`dir'"
	}
* end

* Create folder structure for project. This creates a consistent file folder structure
local folders Rawdata Dofile Dataout Export
foreach dir in `folders' {
	confirmdir "`dir'"
	if `r(confirmdir)'==170 {
			mkdir "`dir'"
			disp in yellow "`dir' successfully created."
		}
	else disp as error "`dir' already exists. Skipped to next folder."
}
*end

/*---------------------------------
# Set Globals based on path above #
-----------------------------------*/
global date $S_DATE
local dir `c(pwd)'
global path "`dir'"
global pathdo "`dir'/Dofiles"
global pathout "`dir'/Dataout"
global pathraw "`dir'/Rawdata"
global pathexport "`dir'/Export"
cd $path

* Create folders for the dataout
global datapath "/Users/cadelson/Documents/Github/UgandaPHIA/Rawdata/"

* Get out houseohld region and id
use "$datapath/Uphia2016hh.dta", clear

keep householdid region
save "$pathout/UGA_hh_dta", replace

* Bring in kids info and restrict to variables of interest
use "$datapath/Uphia2016adultbio.dta", clear

* Keep variables needed for analysis
keep hivstatusfinal age  householdid personid bt_status gender btwt* var*

merge m:1 householdid using "/Users/cadelson/Documents/Github/UgandaPHIA/Dataout/UGA_hh_dta.dta"
* 1,414 households do not have matches for whatever reason

* Pluck out the range we need
keep if inrange(age, 15, 24)

tab region age if bt_status == 1 
keep if bt_status != 9

* Trying to create condensed hiv estimate var, but will use official one per documentation
g byte hiv = hivstatusfinal == 1 & bt_status == 1

egen agecat = cut(age), at(15, 20, 25) label
la def ages 0 "15-19" 1 "20-24"
la val agecat ages

* Check tabulations 
bysort region: tab3way agecat region hiv if bt_status == 1 & gender == 2

* Creating a new disaggregation variable for estimates, creates number for each combonation of age group and region
egen agecat_reg = group(region agecat)
tab3way reg agecat agecat_reg

* Declare data to be survey set using  jacknife methood
svyset [pw=btwt0], jkrweight(btwt001-btwt253, multiplier(1)) vce(jackknife) dof(25)

* loop over regions to check estimates
forvalues i = 1/10 {
 display in red "`i'"
 svy: tab hivstatusfinal agecat if hivstatusfinal!=99 & gender == 2 & region == `i', col se ci obs format(%8.3g)

}

 svy: tab hivstatusfinal agecat_reg if hivstatusfinal!=99 & gender == 2, col se ci obs format(%8.3g)

 
 *My previous estimation
table agegroup hivstatusfinal region
table agegroup hivstatusfinal region if gender==2

