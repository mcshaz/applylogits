# applylogits
Stata ado file to apply multiple covariates and models to risk adjust data

### Use
This is designed for when multiple risk models evolve over time such that coefficients are updated (recalibration) or covariates are added/removed, and the values of the coefficients are more eaily kept track of and appended to in an Excel spreadsheet

### Options
- debug - wil execute a gen float [x] = ... for each covariate supplied (i.e. each cell under the covariate header *except* intercept), and thereby break down the larger formula to help determine which formula contains a syntax error, or which variable is not of the appropriate Stata type to convert to float
- or - supplied values ar odds ratios rather than log odds

### Example
The Paediatric Index of Mortality (PIM) model has undergone multiple evolutions and recalibrations over time - as detailed in the table below

covariate | missing | PIM | PIM2 | PIM2_2008 | PIM3 | PIM3_2013 | PIM3_2015
----------|---------|-----|------|-----------|------|-----------|----------
pupils | 0 | 2.357 | 3.0791 | 4.613758 | 3.8233 | 4.371172 | 4.524262
elective | 0 |  | -0.9282 | -0.2564245 | -0.5378 | -0.5164336 | -0.3676672
rs_hr124 | 0 | 1.342 | 1.3352 | 1.087207 | 0.9763 | 0.6634843 | 1.062791
cond(inlist(be_source,1,2),abs(bea),0) | 0 | 0.071 | 0.104 | 0.0606854 | 0.0671 | 0.0740947 | 0.0651518
sbpa | 120 |  |  |  | -0.0431 | -0.0296888 | -0.0359887
sbpa^2/1000 | 14.4 |  |  |  | 0.1716 | 0.0964949 | 0.1214007
inlist(bypass,1,3) | 0 |  |  |  | -1.2246 | -1.866951 | -2.302574
inlist(cardiac,1,3) & !inlist(bypass,1,3) | 0 |  |  |  | -0.8762 | -1.318171 | -1.40127
recovery & !inlist(cardiac,1,3) & !inlist(bypass,1,3) | 0 |  |  |  | -1.5164 | -1.572421 | -2.040691
pim3_vhr!=0 | 0 |  |  |  | 1.6225 | 1.993498 | 2.202997
pim3_hr!=0 | 0 |  |  |  | 1.0725 | 1.368355 | 1.460924
pim3_lr!=0 | 0 |  |  |  | -2.1766 | -2.401701 | -1.750197
100 * fio2a / po2a | 0.23 |  |  |  | 0.4214 | 0.5181944 | 0.2747865
100 * fio2a / po2a | 0 | 0.415 | 0.2888 | 0.3986429 |  |  | 
abs(sbpa - 120) | 0 | 0.021 | 0.01395 | 0.0100186 |  |  | 
recovery | 0 |  | -1.0244 | -1.864904 |  |  | 
inlist(bypass,1,3) | 0 |  | 0.7507 | -0.1319602 |  |  | 
!inlist(pim_uc,0,8) | 0 |  | 1.6829 | 1.702392 |  |  | 
pim_lr!=0 | 0 |  | -1.577 | -2.1124 |  |  | 
pim_uc!=0 | 0 | 1.826 |  |  |  |  | 
planned==1 | 0 | -1.552 |  |  |  |  | 
intercept |  | -4.873 | -4.8841 | -4.598864 | -1.7928 | -2.299542 | -2.189059

Applylogits requires 1 column named covariate, and an optional column named missing, which is the default value to use if the variable is not present/unknown. If there is no column with a heading missing, the usual stata behavior is follwed where a missing value for any of the variables used in the formula will generate a value of missing.
1 covariate must be named intercept.

### use
```stata
use "C:\myfolder\picu.dta"
gen died = inlist(outcome,2,5)
mvdecode pupils elective rs_hr124 be_source bea sbpa fio2a po2a bypass cardiac recovery pim3_vhr pim3_hr pim3_lr recovery pim_uc pim_lr pim_uc planned, mv(999)
destring planned, replace
keep if dis_dt >= tc(1jan2017 00:00:00) & dis_dt < tc(1jan2018 00:00:00)
applylogits using "C:\myfolder\PIM calibrations.xlsx", debug
```

which will display the Stata commands as they get executed

    gen float PIM = invlogit(0 + 2.357 * cond(missing(pupils),0,pupils) + 1.342 * cond(missing(rs_hr124),0,rs_hr124) + .071 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + .415 * cond(missing(fio2a,po2a),0,100 * fio2a / po2a) + -4.873 + .021 * cond(missing(sbpa),0,abs(sbpa - 120)) + 1.826 * cond(missing(pim_uc),0,pim_uc!=0) + -1.552 * cond(missing(planned),0,planned==1))
    gen float PIM2 = invlogit(0 + 3.0791 * cond(missing(pupils),0,pupils) + -.9282 * cond(missing(elective),0,elective) + 1.3352 * cond(missing(rs_hr124),0,rs_hr124) + .104 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + .2888 * cond(missing(fio2a,po2a),0,100 * fio2a / po2a) + -4.8841 + .01395 * cond(missing(sbpa),0,abs(sbpa - 120)) + -1.0244 * cond(missing(recovery),0,recovery) + .7507 * cond(missing(bypass),0,inlist(bypass,1,3)) + 1.6829 * cond(missing(pim_uc),0,!inlist(pim_uc,0,8)) + -1.577 * cond(missing(pim_lr),0,pim_lr!=0))
    gen float PIM2_2008 = invlogit(0 + 4.613758 * cond(missing(pupils),0,pupils) + -.2564245 * cond(missing(elective),0,elective) + 1.087207 * cond(missing(rs_hr124),0,rs_hr124) + .0606854 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + .3986429 * cond(missing(fio2a,po2a),0,100 * fio2a / po2a) + -4.598864 + .0100186 * cond(missing(sbpa),0,abs(sbpa - 120)) + -1.864904 * cond(missing(recovery),0,recovery) + -.1319602 * cond(missing(bypass),0,inlist(bypass,1,3)) + 1.702392 * cond(missing(pim_uc),0,!inlist(pim_uc,0,8)) + -2.1124 * cond(missing(pim_lr),0,pim_lr!=0))
    gen float PIM3 = invlogit(0 + 3.8233 * cond(missing(pupils),0,pupils) + -.5377999999999999 * cond(missing(elective),0,elective) + .9763 * cond(missing(rs_hr124),0,rs_hr124) + .0671 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + -.0431 * cond(missing(sbpa),120,sbpa) + .1716 * cond(missing(sbpa),14.4,sbpa^2/1000) + -1.2246 * cond(missing(bypass),0,inlist(bypass,1,3)) + -.8762 * cond(missing(cardiac,bypass),0,inlist(cardiac,1,3) & !inlist(bypass,1,3)) + -1.5164 * cond(missing(recovery,cardiac,bypass),0,recovery & !inlist(cardiac,1,3) & !inlist(bypass,1,3)) + 1.6225 * cond(missing(pim3_vhr),0,pim3_vhr!=0) + 1.0725 * cond(missing(pim3_hr),0,pim3_hr!=0) + -2.1766 * cond(missing(pim3_lr),0,pim3_lr!=0) + -1.7928 + .4214 * cond(missing(fio2a,po2a),.23,100 * fio2a / po2a))
    gen float PIM3_2013 = invlogit(0 + 4.371172 * cond(missing(pupils),0,pupils) + -.5164336000000001 * cond(missing(elective),0,elective) + .6634843 * cond(missing(rs_hr124),0,rs_hr124) + .0740947 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + -.0296888 * cond(missing(sbpa),120,sbpa) + .0964949 * cond(missing(sbpa),14.4,sbpa^2/1000) + -1.866951 * cond(missing(bypass),0,inlist(bypass,1,3)) + -1.318171 * cond(missing(cardiac,bypass),0,inlist(cardiac,1,3) & !inlist(bypass,1,3)) + -1.572421 * cond(missing(recovery,cardiac,bypass),0,recovery & !inlist(cardiac,1,3) & !inlist(bypass,1,3)) + 1.993498 * cond(missing(pim3_vhr),0,pim3_vhr!=0) + 1.368355 * cond(missing(pim3_hr),0,pim3_hr!=0) + -2.401701 * cond(missing(pim3_lr),0,pim3_lr!=0) + -2.299542 + .5181944000000001 * cond(missing(fio2a,po2a),.23,100 * fio2a / po2a))
    gen float PIM3_2015 = invlogit(0 + 4.524262 * cond(missing(pupils),0,pupils) + -.3676672 * cond(missing(elective),0,elective) + 1.062791 * cond(missing(rs_hr124),0,rs_hr124) + .0651518 * cond(missing(be_source,bea),0,cond(inlist(be_source,1,2),abs(bea),0)) + -.0359887 * cond(missing(sbpa),120,sbpa) + .1214007 * cond(missing(sbpa),14.4,sbpa^2/1000) + -2.302574 * cond(missing(bypass),0,inlist(bypass,1,3)) + -1.40127 * cond(missing(cardiac,bypass),0,inlist(cardiac,1,3) & !inlist(bypass,1,3)) + -2.040691 * cond(missing(recovery,cardiac,bypass),0,recovery & !inlist(cardiac,1,3) & !inlist(bypass,1,3)) + 2.202997 * cond(missing(pim3_vhr),0,pim3_vhr!=0) + 1.460924 * cond(missing(pim3_hr),0,pim3_hr!=0) + -1.750197 * cond(missing(pim3_lr),0,pim3_lr!=0) + -2.189059 + .2747865 * cond(missing(fio2a,po2a),.23,100 * fio2a / po2a))

these newly created variables can then be used for example to generated SMRs (Standardised Mortality Ratios):

```stata
foreach v of varlist PIM- PIM3_2015 {
  di "`v'"
  oeratio died `v'
}
```

which will give the output

    PIM
    positive outcomes observed = 41 (95% Confidence interval 27.531443 - 54.468557)
    positive outcomes expcted = 66.494516
    Standardized Ratio = .6165922
    95% Confidence interval .4140408 - .81914359
    z = -3.7099991 (< 1st centile)
    PIM2 ...
   
Ando so on for each of the models in the table above. *for help on the above user written command, type 'findit oeratio' in Stata*

The data can also be used to generate real time control graphs, such as
```stata
sort dis_dt
gen seq = _n
mydatelabels seq = ceil(month( dofc(dis_dt) )/3),local(mymac) start format(%tcMon_'YY)
tabcusum died seq, pred(PIM3_2015) limit(95 99) xlabel(`mymac', axis(2)) xaxis(1 2)
```
