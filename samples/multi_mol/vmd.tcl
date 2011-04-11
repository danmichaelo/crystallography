
display rendermode GLSL

package require crystallography_gui
vmd_install_extension crystallography cryst_tk "Crystallography"

crystal_debug on
cryst_tk

# Load a molecule with unit cell data
mol new {1CRN.pdb} type {pdb} waitfor -1

# and one without
mol new {ice.pdb} type {pdb} waitfor -1

#crystal_axes on

