
display rendermode GLSL

# Load crystallography package if it hasn't been loaded already 
if { [catch {package present crystallography_gui}] } {
    vmd_install_extension crystallography_gui cryst_tk "Crystallography"
}

crystal_debug on
cryst_tk

# Load a molecule with unit cell data
mol new {1CRN.pdb} type {pdb} waitfor -1

# one with a hexagonal cell
mol new {quartz.POSCAR} type {POSCAR} waitfor -1

# and one without
mol new {ice.pdb} type {pdb} waitfor -1

#crystal_axes on

