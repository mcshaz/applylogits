program applylogits
version 13.1
syntax using [if] [in] [, DEBUG OR]
//debug - check each covariate expression will work individually
//or covariates ar odds ratios
qui ds
local allvars `r(varlist)'

tempfile tempdata
save "`tempdata'"

import excel `using', firstrow clear

qui ds
local models `r(varlist)'
local models = subinword("`models'","covariate","",1)
local missingdefaults = strpos(" `models' ", " missing ")>0
local models = subinword("`models'","missing","",1)

qui count if covariate == "intercept"
if r(N) != 1 {
	di as error "expected 1 covariate named intercept - found `r(N)'"
	use `tempdata', clear
	exit 2000
} 

local covarcount `=_N'

local unfound 0
if `missingdefaults' | "`debug'" != "" {
	forvalues i = 1(1)`covarcount' {
		local exp = covariate[`i']
		if ("`exp'" != "intercept" & "`exp'" != "") {
			if `missingdefaults' {
				findvariables `exp', vars(`allvars')
				if "`r(vars)'" == "" {
					di as error "could not find variable name in expression: `exp'"
					local unfound 1
				}
				local vars`i' = subinstr("`r(vars)'"," ",",",.)
			}
			if "`debug'" != "" {
				local debug`i' `exp'
			}
		}
	}
	if `unfound' {
		use `tempdata', clear
		exit 2000
	}
}

foreach m in `models' {
	local model`m' gen float `m' = invlogit(0 //0 so that + is still valid
	forvalues i = 1(1)`=_N' {
		local coef = `m'[`i']
		local exp = covariate[`i']
		if "`exp'" == "intercept" {
			if missing(`coef') {
				di as error "no real intercept value found for model `m'"
				local unfound 1
			}
			local model`m' `model`m'' + `coef'
		}
		else if (!missing(`coef')){
			if ("`or'"!=""){
				local coef = exp(`coef')
			}
			if `missingdefaults' {
				local default = missing[`i']
				local model`m' `model`m'' + `coef' * cond(missing(`vars`i''),`default',`exp')
			}
			else {
				local model`m' `model`m'' + `coef' * (`exp')
			}	
		}
	}
	local model`m' `model`m'') `if' `in'
}

use `tempdata', clear
if "`debug'" != "" {
	tempvar trialgen
	qui gen float `trialgen' = .
	forvalues i = 1(1)`covarcount' {
		if "`debug`i''" != "" {
			capture replace `trialgen' = `debug`i''
			if _rc != 0 {
				di as error "expression: `debug`i'' gave return code `=_rc'"
				local unfound 1
			}
		}
	}
}
if `unfound' {
	if _rc == 0 {
		exit 2000
	}
	else {
		error _rc
	}
}
foreach m in `models' {
	di as text
	di as text "`model`m''"
	`model`m''
}
end

program findvariables, rclass
syntax anything, VARS(namelist)
	local vars = subinstr("`vars'"," ","|",.)
	local nonwordchar [^a-zA-Z0-9_]
	local rx `nonwordchar'(`vars')`nonwordchar'
	while regexm(" `anything' ", "`rx'") {
		if "`returnvar'"=="" | !strpos(" `returnvar' ", " `=regexs(1)' ") {
			local returnvar `returnvar' `=regexs(1)'
		}
		local anything=trim(regexr(" `anything' ", "`rx'", ""))
	}
	return local vars `returnvar'
end
