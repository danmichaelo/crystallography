
#############################################################################
# Rendering
#############################################################################

display rendermode GLSL
#display resize 600 600
display resize 900 500
display resetview
color Display Background gray
color Element Si silver
color Element P red

#############################################################################
# Load a molecule 
#############################################################################

mol new {trajectory.vtf} type {vtf} waitfor -1
mol modselect 0 0 all
mol modstyle 0 0 DynamicBonds 2.900000 0.100000 6.000000
mol modcolor 0 0 Element
mol modmaterial 0 0 Glossy

#############################################################################
# Crystallography
#############################################################################

# Load crystallography package if it hasn't been loaded already 
if { [catch {package present crystallography_gui}] } {
    vmd_install_extension crystallography_gui cryst_tk "Crystallography"
}

#cryst_debug on
cryst_tk
view_along {1 1 1}
view_vectors off

# Tweak lower left position:
array set ::Crystallography::posLowerLeft {x -0.70 y -0.70}
cryst_axes on -position lower-left

# Animate:
set runtime 0.
set totaltime [expr {3.*1000000}] ;# 1 second in microseconds
set relx 1.
while { $runtime < $totaltime } {
  set t [lindex [split [time { 
    set ::Crystallography::posLowerLeft(x) $relx
    cryst_axes on 
  }]] 0]
  set runtime [expr {$runtime + $t}]
  set reltime [expr {$runtime/$totaltime}]
  set relx [expr {-0.78 + 1.6*(1.0-$reltime)**4}]
  display update
}
