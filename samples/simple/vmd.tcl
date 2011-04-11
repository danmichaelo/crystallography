#
# Run as: vmd -e vmd.tcl

#############################################################################
# Rendering
#############################################################################

display rendermode GLSL
display resize 600 600
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

vmd_install_extension crystallography_gui cryst_tk "Crystallography"

#crystal_debug on
cryst_tk
view_along {1 1 0}
crystal_axes on -position lower-left
view_vectors on -position upper-left

