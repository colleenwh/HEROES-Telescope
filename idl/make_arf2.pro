pro make_arf2, nshells, offaxis_angle, balloon_altitude, source_elevation, arffile,$
 summed_eff_area=summed_eff_area, use_cawh_calc=use_cawh_calc
;This code computes the diagonal, non-detector components of the response. This includes the atmospheric transmission and the optics ;effective area, given an off-axis angle. The effective area is interpolated from a table of simulated results at various off-axis ;angles.
;Setting the keyword summed_eff_area sums the effective areas for all 8 optics modules.
;The result is written to a fits file with matching photon energy bins and channel energy bins to the detector response in the rmf file.

arf=replicate({ENERG_LO:0.0, ENERG_HI:0.0, SPECRESP:0.0, EFF_AREA:0.0, ATM_TRANS:0.0},1000)

arf.energ_lo=indgen(1000)*0.0998+0.2
arf.energ_hi=(indgen(1000)+1)*0.0998+0.2

;Read in simulated effective areas for 13 or 14 shells
if keyword_set(summed_eff_area) then begin
  readcol,'txt_files/aeff_13shells_sky.dat',energy,offax0, offax1,offax2,$
   offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12
;interpolate effective areas for selected off-axis angle
  eff_area13=reform([offax0, offax1,offax2,offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12], 251, 13)
  index=fix(offaxis_angle)
  lin_interp_factor = offaxis_angle-index
  offaxis_eff_area13 = eff_area13[*,index]*(1-lin_interp_factor)+eff_area13[*,index+1]*lin_interp_factor
  readcol,'txt_files/aeff_14shells_sky.dat',energy,offax0, offax1,offax2,$
   offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12
;interpolate effective areas for selected off-axis angle
  eff_area14=reform([offax0, offax1,offax2,offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12], 251, 13)
  index=fix(offaxis_angle)
  lin_interp_factor = offaxis_angle-index
  offaxis_eff_area14 = eff_area14[*,index]*(1-lin_interp_factor)+eff_area14[*,index+1]*lin_interp_factor
;combine effective areas for all 8 detectors (3 with 13 shells and 5 with 14 shells)
  arf_energy_mid=(arf.energ_lo+arf.energ_hi)/2.
  tmp=where(arf_energy_mid ge energy[0] and arf_energy_mid le max(energy),ntmp)
  arf[tmp].eff_area=3*spline(energy,offaxis_eff_area13,arf_energy_mid[tmp],/double)+$
    5*spline(energy,offaxis_eff_area14,arf_energy_mid[tmp],/double)
endif else begin
  case nshells of
    13: readcol,'txt_files/aeff_13shells_sky.dat',energy,offax0, offax1,offax2,$
     offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12
    14: readcol,'txt_files/aeff_14shells_sky.dat',energy,offax0, offax1,offax2,$
     offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12
    else: stop,'Invalid number of shells '+string(nshells)+' Allowed values 13 or 14'
  endcase 
  ;interpolate effective areas for selected off-axis angle
  eff_area=reform([offax0, offax1,offax2,offax3,offax4,offax5,offax6,offax7,offax8,offax9,offax10,offax11,offax12], 251, 13)
  index=fix(offaxis_angle)
  lin_interp_factor = offaxis_angle-index
  offaxis_eff_area = eff_area[*,index]*(1-lin_interp_factor)+eff_area[*,index+1]*lin_interp_factor
  arf_energy_mid=(arf.energ_lo+arf.energ_hi)/2.
  tmp=where(arf_energy_mid ge energy[0] and arf_energy_mid le max(energy),ntmp)
  arf[tmp].eff_area=spline(energy,offaxis_eff_area,arf_energy_mid[tmp],/double)
endelse
;Correct effective area for 10% obstructions
arf.eff_Area= arf.eff_area*0.9 

;Calculate Atmopspheric column density
if keyword_set(use_cawh_calc) then $ ;uses Colleens original atmospheric transmission calculation.
 atm_col_density = 3-0.585051*(balloon_altitude-39.624) $ ; assumes 3 g/cm2 at 39.624 km 
else $ 
 atm_col_density=23.5-0.5*balloon_altitude ;from Albert Shih e-mail reporting measurements from MAXIS Antarctic Balloon flight.
print,'Air mass thickness (g/cm2) = ',atm_col_density
;Calculate Atmospheric transmission
readcol,'txt_files/air_mass_atten_coefs.txt',atm_energy,mass_atten,rest
tmp2=where(arf_energy_mid ge min(atm_energy*1000.) and arf_energy_mid le max(atm_energy*1000.))
interp_mass_atten=dblarr(n_elements(arf_energy_mid))
interp_mass_atten[tmp2] = spline(atm_energy*1000.,mass_atten,arf_energy_mid[tmp2],/double)
testen=indgen(251)*0.25+17.5
test_mass_atten = spline(atm_energy*1000.,mass_atten,testen,/double)
arf[tmp2].atm_trans=exp(-atm_col_density/sin(source_elevation*!dtor)*interp_mass_atten[tmp2])
arf.specresp = arf.eff_area*arf.atm_trans

;add parameters to header
fxaddpar,hdr,'TUNIT1','keV','physical unit of field'
fxaddpar,hdr,'TUNIT2','keV','physical unit of field'
fxaddpar,hdr,'TUNIT3','cm**2','physical unit of field'
fxaddpar,hdr,'TUNIT4','cm**2','physical unit of field'
fxaddpar,hdr,'EXTNAME','SPECRESP','binary table extension'
fxaddpar,hdr,'HDUNAME','SPECRESP','block name'
fxaddpar,hdr,'HDUCLASS','OGIP'
fxaddpar,hdr,'HDUVERS','1.1.0'
fxaddpar,hdr,'HDUCLAS1','RESPONSE'
fxaddpar,hdr,'HDUCLAS2','SPECRESP'
fxaddpar,hdr,'TELESCOP','HEROES','Telescope'
if not(keyword_set(summed_eff_area)) then fxaddpar,hdr,'NSHELLS',nshells,'Number of mirror shells in effective area' else $
 fxaddpar,hdr,'COMMENT','Effective area includes all 8 detectors, 3 with 13 shells and 5 with 14 shells.'
fxaddpar,hdr,'AIRMASS',atm_col_density,'Air mass thickness (g/cm2)'
fxaddpar,hdr,'BALLOONALT',balloon_altitude,'Balloon altitude (km)'
fxaddpar,hdr,'SRC_ELV',source_elevation,'Target elevation angle (deg)'
fxaddpar,hdr,'OFFAXANG',offaxis_angle,'Off-axis angle (arcmin)'
;write to file
mwrfits,arf,arffile,hdr,/create
return
end


 
