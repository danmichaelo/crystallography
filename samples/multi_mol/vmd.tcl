
display rendermode GLSL

package require pbctools

# Load crystallography package if it hasn't been loaded already 
if { [catch {package present crystallography_gui}] } {
    vmd_install_extension crystallography_gui cryst_tk "Crystallography"
}

cryst_debug on
cryst_tk

# Load a molecule with orthorhombic unit cell:
set mol1 [mol new {1BUW.pdb} type {pdb} waitfor -1]
pbc box -molid $mol1

# ... and one with a hexagonal cell:
set mol2 [mol new {quartz.POSCAR} type {POSCAR} waitfor -1]
pbc box -molid $mol2

# ... and one without unit cell information:
set mol3 [mol new {ice.pdb} type {pdb} waitfor -1]

#cryst_axes on

