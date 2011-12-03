# Run with `vmd -e scaling.tcl' 
# This testcase is mainly for testing if the drawn
# arrows scale correctly for non-square windows.

# Minimum size (in px):
set s1 300
# Maximum size (in px):
set s2 600



menu main off

mol new POSCAR type POSCAR
mol modstyle 0 0 CPK 0.2 0.2 10.0 6.0

#cryst_debug on
pbc box
view_along {1 -1 0} {0 0 -1}
puts "View is -8 0 6"
#cryst_tk

cryst_axes on -position lower-left


#view_along {-5 0 4} {0 1 0}

display resize $s1 $s1
rotate x by 1
rotate x by -1
for {set i 0} {$i < 200} {incr i} {
 set dx [expr {0.0001*(100**2-($i-100.)**2)}]
 rotate y by $dx
 display update
 after 1
}
for {set i 0} {$i < 200} {incr i} {
 set dx [expr {-0.0001*(100**2-($i-100.)**2)}]
 rotate y by $dx
 display update
 after 1
}


view_vectors on -position upper-left


puts "Viewing ${s1}x${s1} for 2 seconds"
after 2000
display resize $s2 $s1
rotate x by 1
rotate x by -1
puts "Viewing ${s2}x${s1} for 2 seconds"
after 2000
display resize $s1 $s1
rotate x by 1
rotate x by -1
puts "Viewing ${s1}x${s1} for 2 seconds"
after 2000
display resize $s1 $s2
rotate x by 1
rotate x by -1
puts "VIewing ${s1}x${s2} for 2 seconds"
after 2000
display resize $s2 $s2
rotate x by 1
rotate x by -1
puts "Viewing ${s2}x${s2} for 2 seconds"
after 2000
#puts "Resizing to ${s1}x${s1}"
#display resize $s1 $s1

#quit
