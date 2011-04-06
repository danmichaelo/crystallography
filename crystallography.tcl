#############################################################################################
#
# Crystallography VMD plugin
#
# Author: Dan Michael Heggø
#
# This plugin was written to make it easier to project the view direction along 
# crystallographic directions. 
# It adds commands to convert vectors between crystallographic and cartesian coordinates 
# and a simple GUI for setting the view. The GUI is largely inspired by the "Orientation" 
# window of the program VESTA and the "Set View Direction" window of CrystalMaker.
#
# Note that for the plugin to work, the loaded molecule must contain unit cell information.
# 
# usage: cryst
# GUI: cryst_tk
# 
# Add to menu:
# menu tk register "Crystallography" cryst_tk
# or
# vmd_install_extension cryst cryst_tk "Crystallography"
#


#############################################################################################
#                                     Main commands  
#############################################################################################

# Opens the GUI
proc cryst_tk {} {
  ::Crystallography::update
  return [Crystallography::GUI::show_gui]
}

# Converts cartesian coordinate vector of length 3 (4?) to crystallographic coordinates 
proc cart2cryst {vec} {
  ::Crystallography::update
  return [::Crystallography::cart2cryst $vec]
}

# Converts crystallographic coordinate vector of length 3 (4?) to cartesian coordinates
proc cryst2cart {vec} {
  ::Crystallography::update
  return [::Crystallography::cryst2cart $vec]
}

# Set the view to project along {vec} (optional upvec as arg 2)
proc view_along {args} {
  if {[llength $args] == 0} {
    puts "usage: view_along projection_vector [upwards_vector]"
    puts "example: view_along {1 1 1}
    return
  }
  ::Crystallography::update
  eval ::Crystallography::set_view_direction $args
}

proc check_norm {} {
  set rot [molinfo 0 get rotate_matrix]
  for {set i 0} {$i < 3} {incr i} {
    puts [vecdot [lindex $rot 0 $i] [lindex $rot 0 $i]]
  } 
}

#############################################################################################
#                             Some utility functions needed  
#############################################################################################

# Finds the inverse of a 3x3 matrix. From: http://wiki.tcl.tk/14921
proc mat3_inverse {matrix} {
    if {[llength $matrix] != 3 ||
        [llength [lindex $matrix 0]] != 3 ||
        [llength [lindex $matrix 1]] != 3 ||
        [llength [lindex $matrix 2]] != 3} {
        error "wrong sized matrix"
    }
    set inv {{? ? ?} {? ? ?} {? ? ?}}

    # Get adjoint matrix : transpose of cofactor matrix
    for {set i 0} {$i < 3} {incr i} {
        for {set j 0} {$j < 3} {incr j} {
            lset inv $i $j [_cofactor3 $matrix $i $j]
        }
    }
    # Now divide by the determinant
    set det [expr {double([lindex $matrix 0 0]   * [lindex $inv 0 0]
                   + [lindex $matrix 0 1] * [lindex $inv 1 0]
                   + [lindex $matrix 0 2] * [lindex $inv 2 0])}]
    if {$det == 0} {
        error "non-invertable matrix"
    }

    for {set i 0} {$i < 3} {incr i} {
        for {set j 0} {$j < 3} {incr j} {
            lset inv $i $j [expr {[lindex $inv $i $j] / $det}]
        }
    }
    return $inv
}

# Finds the cofactor matrix
proc _cofactor3 {matrix i j} {
    array set COLS {0 {1 2} 1 {0 2} 2 {0 1}}
    foreach {row1 row2} $COLS($j) break
    foreach {col1 col2} $COLS($i) break

    set a [lindex $matrix $row1 $col1]
    set b [lindex $matrix $row1 $col2]
    set c [lindex $matrix $row2 $col1]
    set d [lindex $matrix $row2 $col2]

    set det [expr {$a*$d - $b*$c}]
    if {($i+$j) & 1} { set det [expr {-$det}]}
    return $det
}

# this converts a 3x3 matrix to a 4x4 matrix (adding 'translation') 
proc matrix3to4 {mat} {
  lset mat 0 [linsert [lindex $mat 0] end 0]
  lset mat 1 [linsert [lindex $mat 1] end 0]
  lset mat 2 [linsert [lindex $mat 2] end 0]
  lappend mat {0 0 0 1}
  return $mat
}

# this converts a 4x4 matrix to a 3x3 matrix (removing 'translation') 
proc matrix4to3 {mat} {  
  lset mat 0 [lrange [lindex $mat 0] 0 end-1]
  lset mat 1 [lrange [lindex $mat 1] 0 end-1]
  lset mat 2 [lrange [lindex $mat 2] 0 end-1]
  set mat [lrange $mat 0 end-1]
  return $mat
}

#############################################################################################
#                               Crystallography "class"  
#############################################################################################

package provide crystallography 1.0

namespace eval ::Crystallography:: {
  
  puts "DEBUG: init Crystallography"
  
  set listenersEnabled 0     ;# whether the event listeners (Tcl "tracers") are activated or not
  #set crystallographyState off
  set crystallographyColor black   ;# use a dark foreground color? 
  set currentMol [molinfo top]     ;# mol of study
  set canvasMol -1                 ;# mol in which the drawing is done
  set canvasMolScale 1.            ;# scale of the canvas mol
  array set displaySize {x 1 y 1 z 1}    ;# size of window
  set latticeParam { 0 0 0 0 0 0 }
  set unitCellVol 0                ;# unit cell volume in Ang**3

  # 4x4 transformation matrix in cartesian coordinates:
  set unitCell {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}
	
  # inverse matrix:
  set unitCellInv {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}  
  
  # Drawings:
  set drawViewVectors 0
  set drawCrystAxes 0
}

#proc ::Crystallography::toggle_Crystallography {args} {
#    if {$listenersEnabled == 1} disable_Crystallography else enable_Crystallography
#}

proc ::Crystallography::debug {str} {
  puts "DEBUG: $str"
}

proc ::Crystallography::update {} {
  variable currentMol

  # debug "update"

  # check if a molecule has been selected  
  
  if { [catch { molinfo $currentMol get id } ] } {
    # Try to get top molecule:
    if { [catch { molinfo top get id } top_id ] } {
      puts "Error: no molecule loaded"
      return
    }
    set currentMol top_id
  }

  # check if PBCs changed

  read_pbc
  
  # Update drawings

  variable canvasMol
  variable canvasMolScale
  variable displaySize  
  variable drawCrystAxes
  variable drawViewVectors
  
  
  if {$drawCrystAxes || $drawViewVectors} {

    # re-orient canvas
    molinfo $canvasMol set center_matrix [list [transidentity]]
    molinfo $canvasMol set rotate_matrix [list [transidentity]]
    molinfo $canvasMol set global_matrix [list [transidentity]]
    molinfo $canvasMol set scale_matrix  [molinfo $currentMol get scale_matrix]  
    set canvasMolScale [lindex [molinfo $currentMol get scale_matrix] 0 0 0]

    # read display size
    set canvasMolScale [lindex [molinfo $canvasMol get scale_matrix] 0 0 0]
    set displaySize(y) [expr 0.25*[display get height]/$canvasMolScale]
    set displaySize(x) [expr $displaySize(y)*[lindex [display get size] 0]/[lindex [display get size] 1]]
    if [string equal [display get projection] "Orthographic"] {
      set displaySize(z) [expr (2.-[display get nearclip]-0.001)/$canvasMolScale]
    } else {
      set displaySize(z) 0.
    }

    # clear canvas
    graphics $canvasMol delete all
    graphics $canvasMol material Opaque
    graphics $canvasMol color $::Crystallography::Crystallography_color
    
    # and draw
    if {$drawCrystAxes} {draw_CrystallographicAxes}
  }

}

proc ::Crystallography::read_pbc {} {
  variable unitCell
  variable unitCellInv
  variable unitCellVol
  variable latticeParam
  variable currentMol
  
  set p [ lindex [ pbc get -molid $currentMol ] 0] 
  if {$p == $latticeParam} return     ;# nothing changed, no need to continue
  
  set latticeParam $p
  debug "Got new lattice parameters:"
  debug "$latticeParam"
  
  # [pbc get] returns { { a b c alpha beta gamma } }
  set a [lindex $p 0] 
  set b [lindex $p 1] 
  set c [lindex $p 2]  
  set alpha [::util::deg2rad [lindex $p 3]]
  set beta [::util::deg2rad [lindex $p 4]]
  set gamma [::util::deg2rad [lindex $p 5]]

  # Unit cell volume:
  set unitCellVol [ expr $a*$b*$c*sqrt( 1 - cos($alpha)**2 - cos($beta)**2 - cos($gamma)**2 + 2*cos($alpha)*cos($beta)*cos($gamma) ) ]
  
  # a vector:
  lset unitCell 0 0 $a 
  lset unitCell 1 0 0 
  lset unitCell 2 0 0 

  # b vector:
  lset unitCell 0 1 [ expr $b*cos($gamma) ] 
  lset unitCell 1 1 [ expr $b*sin($gamma) ] 
  lset unitCell 2 1 0 
  
  # c vector:
  lset unitCell 0 2 [ expr $c*cos($beta) ] 
  lset unitCell 1 2 [ expr $c*cos($alpha)-cos($beta)*cos($gamma)/sin($gamma) ] 
  lset unitCell 2 2 [ expr $unitCellVol/($a*$b*sin($gamma)) ] 
  
  set unitCellInv [ matrix3to4 [ mat3_inverse [ matrix4to3 $unitCell ] ] ]
  
}

proc ::Crystallography::vecproj { u v } {
  if {abs([vecdot $u $v]) < 1e-16} {
  	puts "Error in ::Crystallography::vecproj: Vectors u anv v are orthogonal"
  }
  return [vecscale [expr [vecdot $v $u] / [vecdot $u $u]] $u]
}

proc ::Crystallography::cryst2cart { vec } {
  variable unitCell
  variable currentMol
  if {$currentMol == -1} return
  return [vecnorm [coordtrans $unitCell $vec ]]
}

proc ::Crystallography::cart2cryst { vec } {
  variable unitCellInv
  variable currentMol
  if {$currentMol == -1} return
  return [ coordtrans $unitCellInv $vec ]
}

# To specify the view uniquely, two orthogonal vectors are needed. 
# To view along the 110 vector (z vector), with the 001 vector pointing upwards on the screen (y direction):
# set_view_direction {1 1 0} {0 0 1}
# To view along the 110 (z vector) and automaticly calculate y (non-uniquely!):
# set_view_direction {1 1 0}
proc ::Crystallography::set_view_direction { args } {
  variable unitCell
  variable unitCellInv
  variable currentMol
  if {$currentMol == -1} return
  
  # set z vector (projection vector)
  if {[lindex $args 0] == [veczero]} { puts "What is life like along the zero vector? Perhaps mathematicians know?"; return; }
  set z_vec [ cryst2cart [lindex $args 0] ]
  
  # set y vector ("upwards" vector)
  if { [llength $args] > 1 } {
    set y_vec [ cryst2cart [lindex $args 1] ]
  } else {
    set y_vec [ cryst2cart {0 0 1} ]   ;# hmm, would some qualified guess be better ?
  }
  
  # Check if z and y are orthogonal
  set y_ok 1
  if { abs([vecdot $z_vec $y_vec]) > 1e-4} {
     debug "y and z are not orthogonal"
    if {[llength $args] > 1} {
      # TODO: implement a non-GUI alternative? something like gets stdin answer
      set answer [tk_messageBox -message "An upward vector non-orthogonal ([expr abs([vecdot $z_vec $y_vec])]) to the projection vector will give the molecule a stretched, rather peculiar look. Do you want to make the upward vector orthogonal to the projection vector?" -type yesno -default yes -icon warning]
      switch -- $answer {
        yes { 
          set y_ok 0
        }
      }
    } else {
      set y_ok 0
    }
  }
  # Check if z and y are parallel
  if { abs([vecdot $z_vec $y_vec]) > 1-1e-10} {
     debug "y and z are parallel"
     # Define new y vector 
     set y_vec {0 1 0}
  }
  if { abs([vecdot $z_vec $y_vec]) > 1-1e-10 } {
     set y_vec {1 0 0}
  }
  if { abs([vecdot $z_vec $y_vec]) > 1-1e-10 } {
     set y_vec {0 0 1}
  }
  if { abs([vecdot $z_vec $y_vec]) > 1-1e-10 } {
	puts "Error: z and y are parallel!"
  }

  if { $y_ok == 0 } {
    # subtract from y_vec the projection of y_vec onto z_vec (Gram Schmidt orthogonalization)
    
    set y_vec [vecnorm [ vecsub $y_vec [vecproj $z_vec $y_vec] ]]

    #set b [ coordtrans $unitCell_inv $upvec ]
    
    # The GUI should have a listener we could poll
		#set upvec_0 [lindex $upback 0]
		#set upvec_1 [lindex $upback 1]
		#set upvec_2 [lindex $upback 2]
  }
  
  # set x vector ("rightwards" vector)
  set x_vec [vecnorm [veccross $y_vec $z_vec]]
  
  # Define new 4x4 rotation matrix...
  set rot "{{$x_vec 0} {$y_vec 0} {$z_vec 0} {0 0 0 1}}"
  
  # ... and apply it
  #display resetview
  foreach molid [molinfo list] {
    # Perhaps we should exclude molecules that are not real molecules (that contain no atoms?)
    molinfo $molid set rotate_matrix $rot
  }
  #redraw
  update
}



#############################################################################################
#                                   Drawing section
#############################################################################################

proc ::Crystallography::toggleViewVectors {enabled} {
  variable drawViewVectors
  set drawViewVectors $enabled
  drawSettingsChanged
}

proc ::Crystallography::toggleCrystAxes {enabled} {
  variable drawCrystAxes
  set drawCrystAxes $enabled
  drawSettingsChanged
}

proc ::Crystallography::drawSettingsChanged {} {
  variable drawCrystAxes
  variable drawViewVectors
  debug "drawSettingsChanged"
  if {$drawCrystAxes || $drawViewVectors} {
  debug "enable"
    check_canvas
    enable_listeners
  } else {
    disable_listeners
  }  
}

proc ::Crystallography::check_canvas {} {
  variable canvasMol
  variable currentMol
  if {![catch {molinfo $canvasMol get id}]} return   ;# Canvas exists
  debug "CREATING CANVAS"

  # Create canvas mol for drawing:
  set canvasMol [mol new]
  mol rename $canvasMol "Crystallography Canvas"
  if {$currentMol >= 0} {
    mol top $currentMol
    molinfo $canvasMol set scale_matrix [molinfo $currentMol get scale_matrix]  
  }
  debug " ok"
}

proc ::Crystallography::enable_listeners {args} {
  variable listenersEnabled
  variable crystallographyState
  variable currentMol
  variable canvasMol
  global vmd_frame
  global vmd_quit

  if {$listenersEnabled} return                        ;# already active
  if {[catch {molinfo $currentMol get name}]} return   ;# no molecules loaded yet

  debug "enable listeners"
  
  trace add variable ::vmd_logfile write ::Crystallography::on_vmd_event
  trace add variable vmd_frame write ::Crystallography::on_vmd_event
  trace add variable vmd_quit write ::Crystallography::on_vmd_quit
  
  set listenersEnabled 1

  reset_colors  
  update

}

proc ::Crystallography::disable_listeners {} {
  variable listenersEnabled
  variable canvasMol

  if {$listenersEnabled == 0} return                    ;# already inactive

  debug "disable listeners"

  trace remove variable ::vmd_logfile write ::Crystallography::on_vmd_event
  trace remove variable vmd_frame write ::Crystallography::on_vmd_event
  trace remove variable ::vmd_quit write ::Crystallography::on_vmd_quit

  catch {mol delete $canvasMol}
  set listenersEnabled 0
}

proc ::Crystallography::on_vmd_event { args } {
  if {"[lindex $args 0]" == "vmd_logfile"} {
    #puts [format "Log entry: %s" $::vmd_logfile]
    if {"$::vmd_logfile" == "exit"} {
      puts "Crystallography plugin info) VMD is exiting"
      return
    }
  }
  update
}

proc ::Crystallography::on_vmd_quit { args } {
  puts "Crystallography plugin info) Got vmd_quit event"
  disable_Crystallography
}

proc ::Crystallography::reset_colors {} {
  variable Crystallography_color
  if [display get backgroundgradient] {
    set backlight [eval vecadd [colorinfo rgb [color Display BackgroundBot]]]
  } else {
    set backlight [eval vecadd [colorinfo rgb [color Display Background]]]
  }
  if {$backlight <= 1.2} {
    set Crystallography_color white
  } else {
    set Crystallography_color black
  }
}

proc ::Crystallography::draw_arrow {start vec label} { 
  variable canvasMol
  variable displaySize
  set disp "$displaySize(x) $displaySize(y) $displaySize(z)"
  
  set tip_arrow_len 0.2
  set arrow_thickness 2

  set a1start [ vecmul $start $disp ]
  set a1end [ vecadd $a1start [ vecmul $vec $disp ] ]

  set veclen [ veclength [vecsub $a1end $a1start] ]
  # Only show vector if its length exceeds a minimum treshold:
  if { $veclen > 0.1 } {

	  graphics $canvasMol line $a1start $a1end width $arrow_thickness
	  
	  set tip_r [ vectrans [transaxis z 45] [ vecscale -$tip_arrow_len $vec ] ]
	  graphics $canvasMol line $a1end "[ vecadd $a1end [ vecmul $tip_r $disp] ]" width $arrow_thickness
	
	  set tip_l [ vectrans [transaxis z -45] [ vecscale -$tip_arrow_len $vec ] ]
	  graphics $canvasMol line $a1end "[ vecadd $a1end [ vecmul $tip_l $disp] ]" width $arrow_thickness
	  
	  graphics $canvasMol text [ vecadd $a1end [ vecscale 0.2 [ vecnorm [vecsub $a1end $a1start] ]]] "$label"
  }
}

proc ::Crystallography::draw_CrystallographicAxes {} {
  variable canvasMol
  variable canvasMolScale
  variable displaySize
  variable canvasMol
  variable unitCell

  set disp "$displaySize(x) $displaySize(y) $displaySize(z)"
  
  # Scale vector to integers (e.g. [0.7 0 0.7] -> [1 0 1])
  #puts " "
  set vec [list]
  set scaled_vec [list]
  for {set i 0} {$i < 3} {incr i} {
    # Transform cartesian to crystallographic coordinates:
    set ivec [ cart2cryst [lindex [molinfo 0 get rotate_matrix] 0 $i]]
    set scale 1
    for {set j 0} {$j < 3} {incr j} {
      if [ expr [lindex $ivec $j] > 0.001 && [lindex $ivec $j] < $scale ] { set scale [lindex $ivec $j] }
    }
    lappend vec $ivec
    lappend scaled_vec [vecscale [ expr 1/$scale] $ivec]
  }
  
  graphics $canvasMol text [ vecmul {-0.3 -0.9 1} $disp ] [ format "Projection vector: \[%0.2f %0.2f %0.2f\]" [lindex $vec 2 0] [lindex $vec 2 1] [lindex $vec 2 2]] size 1.0
  graphics $canvasMol text [ vecmul {-0.3 -0.95 1} $disp ] [ format "Upward vector: \[%0.2f %0.2f %0.2f\]" [lindex $vec 1 0] [lindex $vec 1 1] [lindex $vec 1 2]] size 1.0

  # a vector:
  # a vector in plane:
  set rot [lindex [molinfo 0 get rotate_matrix] 0]

  set a [ vecnorm [list [lindex $unitCell 0 0] [lindex $unitCell 1 0] [lindex $unitCell 2 0]  [lindex $unitCell 3 0] ]]
  set a_x [ vecdot $a [lindex $rot 0]]
  set a_y [ vecdot $a [lindex $rot 1]]
  #puts "x: $a_x, y: $a_y"

  set b [ vecnorm [list [lindex $unitCell 0 1] [lindex $unitCell 1 1] [lindex $unitCell 2 1]  [lindex $unitCell 3 1] ]]
  set b_x [ vecdot $b [lindex $rot 0]]
  set b_y [ vecdot $b [lindex $rot 1]]

  set c [ vecnorm [list [lindex $unitCell 0 2] [lindex $unitCell 1 2] [lindex $unitCell 2 2]  [lindex $unitCell 3 2] ]]
  set c_x [ vecdot $c [lindex $rot 0]]
  set c_y [ vecdot $c [lindex $rot 1]]

  draw_arrow {-0.80 -0.80 1} "[expr 0.2*$a_x] [expr 0.2*$a_y] 0" "a"
  draw_arrow {-0.80 -0.80 1} "[expr 0.2*$b_x] [expr 0.2*$b_y] 0" "b"
  draw_arrow {-0.80 -0.80 1} "[expr 0.2*$c_x] [expr 0.2*$c_y] 0" "c"
  
#  set orientation_x [format "%1.3f %1.3f %1.3f" [lindex $rot 0 0 0] [lindex $rot 0 0 1] [lindex $rot 0 0 2]]
  
}


