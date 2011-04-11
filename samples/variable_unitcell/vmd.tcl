
color Display Background gray
color Element Si silver
color Element P red

# Background loading takes very long time for such long trajectories,
# so we load everything at once (waitfor -1). Then we can jump back and
# forth in the animation.
mol new {POSCAR} type {POSCAR} waitfor -1
mol new {trajectory.vtf} type {vtf} waitfor -1

#############################################################################
# Representations
#############################################################################

mol modcolor 0 0 ColorID 15
mol modstyle 0 0 CPK 0.300000 0.200000 10.000000 6.000000

mol modselect 0 1 element P
mol modstyle 0 1 VDW 0.200000 8.000000
mol modcolor 0 1 Element
mol modmaterial 0 1 Glossy

mol addrep 1
mol modselect 1 1 element Si
mol modstyle 1 1 VDW 0.200000 8.000000
mol modcolor 1 1 Element
mol modmaterial 1 1 Glossy

mol modstyle 0 1 VDW 0.200000 10.000000
mol modstyle 1 1 VDW 0.200000 10.000000

#############################################################################
# Rendering
#############################################################################

display rendermode GLSL
display resize 600 600
display resetview
scale by 1.2

##
pbc box
vmd_install_extension crystallography_gui cryst_tk "Crystallography"
cryst_tk

