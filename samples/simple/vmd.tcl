#
# Run as: vmd -e vmd.tcl

#############################################################################
# Rendering
#############################################################################

display rendermode GLSL
display resize 500 500
display resetview
color Display Background white
color Element Si blue
color Element O red

#############################################################################
# Load a molecule 
#############################################################################

mol new {quartz.POSCAR} type {POSCAR} waitfor -1
mol modselect 0 0 all
mol modstyle 0 0 VDW 0.300000 12.000000
mol modcolor 0 0 Element
mol modmaterial 0 0 Glossy

pbc box -style arrows

#############################################################################
# Crystallography
#############################################################################

# Load crystallography package if it hasn't been loaded already 
if { [catch {package present crystallography_gui}] } {
    vmd_install_extension crystallography_gui cryst_tk "Crystallography"
}

cryst_debug on
cryst_tk
view_along {0 0 1}
cryst_axes on -position lower-right
view_vectors on -position lower-left

