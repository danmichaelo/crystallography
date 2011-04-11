#############################################################################################
#
# Crystallography VMD plugin
#
# This plugin was written primarily to make it easier to align the view direction along 
# specific crystallographic directions. 
# It adds commands to convert vectors between crystallographic and cartesian coordinates 
# and a simple GUI for setting the view. The GUI is largely inspired by the "Orientation" 
# window of the program VESTA and the "Set View Direction" window of CrystalMaker.
#
# For the plugin to work, the loaded molecule must contain unit cell information.
#
# Author: Dan Michael O. Heggø <danmichaelo _at_ gmail.com>
#
# Inspiration gained from the 'ruler' plugin by Jordi Cohen and the 'colorscalebar' 
# plugin by Wuwei Liang
#
#
# usage: cryst
# GUI: cryst_tk
# 
# Add to menu:
#   vmd_install_extension crystallography_gui cryst_tk "Crystallography"
# or 
#   package require crystallography_gui
#   menu tk register "Crystallography" cryst_tk
#
#
# Known bugs:
#  The plugin updates when it receives events from VMD. 
#  VMD do not notify about all events. Examples of events that does not seem to be broudcasted include
#   - smooth rotations: rotate [x | y | z] <angle> <increment>
#   - display resize


#############################################################################################
#                                    Main commands 
#############################################################################################


#########################################
# cart2cryst $vec
#
# Converts a vector of length 3 (4?) from cartesian to crystallographic 
# coordinates using the available unit cell information.
#
proc cart2cryst {vec} {
  ::Crystallography::update
  return [::Crystallography::cart2cryst $vec]
}

#########################################
# cryst2cart $vec
#
# Converts a vector of length 3 (4?) from crystallographic to cartesian
# coordinates using the available unit cell information.
#
proc cryst2cart {vec} {
  ::Crystallography::update
  return [::Crystallography::cryst2cart $vec]
}

#########################################
# view_along $projection_vector [$upward_vector]
#
# Rotates all the loaded molecules so that the z axis of the view (the axis
# pointing out of the screen) becomes aligned with crystal vector 
# $projection_vector of the selected molecule*. With this alignment, there
# is still freedom for rotation about the z axis, so to completely specify
# a given view, two vectors have to be specified. In this implementation
# a vector $upward_vector to be aligned with the y axis of the view 
# (pointing upwards on the screen) can be specified optionally.
#
# If $projection_vector and $upward_vector are not orthogonal, the 
# $upward_vector is made orthogonal to $projection_vector. This is done
# automatically when using the command line interface, but a notification
# is displayed when using the GUI.
#
# [*] Currently the GUI has to be used to select the correct molecule if 
#     more molecules are loaded.
#
proc view_along {args} {
  if {[llength $args] == 0} {
    puts "usage: view_along projection_vector [upwards_vector]"
    puts "example: view_along {1 1 1}"
    return
  }
  ::Crystallography::update
  eval ::Crystallography::set_view_direction $args
}

##########################################
# crystal_axes on|off
# OPTIONS:
#   -position lower-left|upper-left|lower-right|upper-right
# Toggles the display of the crystal axes. Currently, the GUI provides 
# some more options than the command line interface.
# 
proc crystal_axes {args} {
  if {[llength $args] == 0} {
    puts "usage: crystal_axes on/off"
    puts "example: crystal_axes on"
    return
  }

  if {[lindex $args 0] == "on"} {
    set ::Crystallography::drawCrystAxes 1
  } else {
    set ::Crystallography::drawCrystAxes 0
  }

  # Parse options
  for { set argnum 1 } { $argnum < [llength $args] } { incr argnum } {
	 set arg [ lindex $args $argnum ]
	 set val [ lindex $args [expr $argnum + 1]]
	 switch -- $arg {
		"-position"      { set ::Crystallography::crystAxesLoc [string map {{-} { }} $val]; incr argnum }
		default { error "error: crystallogrpahy: unknown option: $arg" }
	 }
  }

}

##########################################
# view_vectors on|off
# OPTIONS:
#   -position lower-left|upper-left|lower-right|upper-right
#
# Toggles the display of the view vectors. Currently, the GUI provides 
# some more options than the command line interface.
# 
proc view_vectors {args} {
  if {[llength $args] == 0} {
    puts "usage: view_vectors on/off"
    puts "example: view_vectors on"
    return
  }
  if {[lindex $args 0] == "on"} {
    set ::Crystallography::drawViewVectors 1
  } elseif {[lindex $args 0] == "off"} {
    set ::Crystallography::drawViewVectors 0
  }
  # Parse options
  for { set argnum 1 } { $argnum < [llength $args] } { incr argnum } {
	 set arg [ lindex $args $argnum ]
	 set val [ lindex $args [expr $argnum + 1]]
	 switch -- $arg {
		"-position"      { set ::Crystallography::viewVectorsLoc [string map {{-} { }} $val]; incr argnum }
		default { error "error: crystallogrpahy: unknown option: $arg" }
	 }
  }
}

##########################################
# crystal_debug on|off
#
# Toggles the display of debug messages. 
# 
proc crystal_debug {args} {
  if {[llength $args] == 0} {
    puts "usage: crystal_debug on/off"
    puts "example: crystal_debug on"
    return
  }
  if {[lindex $args 0] == "on"} {
    set ::Crystallography::printDebug 1
  } elseif {[lindex $args 0] == "off"} {
    set ::Crystallography::printDebug 0
  }
}

##########################################
# check_norms
#
# Checks if the current unit vectors are orthogonal. This function is for internal
# testing of the plugin.
# 
proc check_norm {} {
    # NOTE: using molinfo 0 instead of molinfo $currentMol !!
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
  set canvasMol -1                 ;# mol in which the drawing is done
  set canvasMolScale 1.            ;# scale of the canvas mol
  array set displaySize {x 1 y 1 z 1}    ;# size of window
  set latticeParam { 0 0 0 0 0 0 }
  set unitCellVol 0                ;# unit cell volume in Ang**3
  set unitCellValid 0			   ;# molecule has unit cell data?
  set pbcChanged 0                 ;# track unitcell
  set orientationChanged 0         ;# track orientation
  set printDebug 0                 ;# print debug messages or not
  set currentFrame -1		       ;# 

  set currentMol [molinfo top]     ;# mol of study
  if { $currentMol == -1 } { set currentMol "none" }
  trace add variable ::Crystallography::currentMol write ::Crystallography::currentMolChanged

  # 4x4 transformation matrix in cartesian coordinates:
  set unitCell {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}
	
  # inverse matrix:
  set unitCellInv {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}  
  
  # Drawing settings:
  set drawCrystAxes 0
  trace add variable ::Crystallography::drawCrystAxes write ::Crystallography::drawSettingsChanged
  set crystAxesScale 100.
  trace add variable ::Crystallography::crystAxesScale write ::Crystallography::drawSettingsChanged
  set crystAxesLoc "lower right"
  trace add variable ::Crystallography::crystAxesLoc write ::Crystallography::drawSettingsChanged

  set drawViewVectors 0
  trace add variable ::Crystallography::drawViewVectors write ::Crystallography::drawSettingsChanged
  set viewVectorsScale 100.
  trace add variable ::Crystallography::viewVectorsScale write ::Crystallography::drawSettingsChanged
  set viewVectorsLoc "lower left"
  trace add variable ::Crystallography::viewVectorsLoc write ::Crystallography::drawSettingsChanged

  array set posLowerLeft {x -0.90 y -0.90}
  array set posUpperLeft {x -0.90 y 0.90}
  array set posLowerRight {x 0.90 y -0.90}
  array set posUpperRight {x 0.90 y 0.90}
}


proc ::Crystallography::debug {str} {
    variable printDebug
    if {$printDebug} { puts "DEBUG: $str" }
}

proc ::Crystallography::update {} {
  variable currentMol
  variable canvasMol
  variable canvasMolScale
  variable displaySize  
  variable drawCrystAxes
  variable drawViewVectors
  variable pbcChanged
  variable orientationChanged
  variable crystColor
  variable unitCellValid
  
  # Update drawings
  #debug " UPDATE"
  if {$drawCrystAxes || $drawViewVectors} {
    if {$pbcChanged || $orientationChanged} {
      # clear canvas
      debug "Clearing canvas"
      graphics $canvasMol delete all
      graphics $canvasMol material Opaque
      graphics $canvasMol color $crystColor
    }
  }
  # check if a molecule has been selected  
  if { [catch { molinfo $currentMol get id } ] } {
    # Try to get top molecule:
    if { [catch { molinfo top get id } top_id ] } {
      debug "Error: no molecule loaded"
      return
    }
    # haz it atmoz?
    if {[molinfo top get numatoms] == 0 } {
      debug "Error: no atoms in top mol"
      return
    }
    # haz it unitcell?
    if {[lindex [pbc get] 0] == 0 } {
      debug "Error: no unit cell infor in top mol"
      return
    }
    debug "Auto-setting molecule: $top_id"
    set currentMol $top_id
  }

  # check if PBCs changed
  set pbcChanged [read_pbc]

  if { $unitCellValid == 0} {
    debug "no unit cell information found"
    return
  }  

  # Update drawings
  if {$drawCrystAxes || $drawViewVectors} {
      if {$pbcChanged || $orientationChanged} {
          set orientationChanged 0

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
    
    #set disp "$displaySize(x) $displaySize(y) $displaySize(z)"
    #puts "D: $disp"
    
    # and draw
    if {$drawCrystAxes} draw_CrystallographicAxes
    if {$drawViewVectors} draw_ViewVectors
    }
  }

}

proc ::Crystallography::read_pbc {} {
  variable unitCell
  variable unitCellInv
  variable unitCellVol
  variable latticeParam
  variable currentMol
  variable unitCellValid
  
  set p [ lindex [ pbc get -molid $currentMol ] 0] 
  if {$p == $latticeParam} { return 0 }    ;# nothing changed, no need to continue
  
  set latticeParam $p
  debug "Got new lattice parameters:"
  debug "$latticeParam"
  if {"[lindex $p 0]" == "0"} {
      debug "no unit cell info found for the selected molecule"
      set unitCellValid 0
      return 1
  }
  set unitCellValid 1
  
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
  return 1
  
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
  variable orientationChanged
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
  if { abs([vecdot $z_vec $y_vec]) > 1e-2} {
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
  set orientationChanged 1
  update

  # update gui if present
  if { ![catch {package present crystallography_gui}] } ::Crystallography::GUI::update_gui
}



#############################################################################################
#                                   Drawing section
#############################################################################################

proc ::Crystallography::currentMolChanged {args} {
  variable currentMol
  debug "Current mol changed to $currentMol"
  drawSettingsChanged
}

proc ::Crystallography::drawSettingsChanged {args} {
  variable drawCrystAxes
  variable drawViewVectors
  variable orientationChanged
  debug "drawSettingsChanged"
  if {$drawCrystAxes || $drawViewVectors} {
    check_canvas
    enable_listeners
    set orientationChanged 1
    update
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

  # Fixes the drawing canvas "molecule". This makes the canvas more stable, but if 
  # the molecule get out of view for some reason, it's harder to get it back into view.
  # This requires some testing.
  mol fix $canvasMol

  if {$currentMol != "none" && $currentMol >= 0} {
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

  if {$listenersEnabled} return                        ;# already active
  #if {[catch {molinfo $currentMol get name}]} return   ;# no molecules loaded yet

  debug "enable listeners"
  
  trace add variable ::vmd_logfile write ::Crystallography::on_vmd_event
  trace add variable ::vmd_frame write ::Crystallography::on_vmd_event
  trace add variable ::vmd_quit write ::Crystallography::on_vmd_quit
  trace add variable ::vmd_initialize_structure write ::Crystallography::on_vmd_event 
  
  set listenersEnabled 1

  reset_colors  

}

proc ::Crystallography::disable_listeners {} {
  variable listenersEnabled
  variable canvasMol

  if {$listenersEnabled == 0} return                    ;# already inactive

  debug "disable listeners"

  trace remove variable ::vmd_logfile write ::Crystallography::on_vmd_event
  trace remove variable ::vmd_frame write ::Crystallography::on_vmd_event
  trace remove variable ::vmd_quit write ::Crystallography::on_vmd_quit
  trace remove variable ::vmd_initialize_structure write ::Crystallography::on_vmd_event 

  catch {mol delete $canvasMol}
  set listenersEnabled 0
}

proc ::Crystallography::on_vmd_event { args } {
  variable orientationChanged
  variable currentMol
  variable currentFrame
  
  debug "EVENT: $args"
  if {"[lindex $args 0]" == "vmd_initialize_structure"} {
    debug "====================================== vmd_initialize_structure"
    set orientationChanged 1
    update
  } elseif {"[lindex $args 0]" == "vmd_logfile"} {
    debug [format "  Log entry: %s" $::vmd_logfile]
    if {"$::vmd_logfile" == "exit"} {
      debug "Crystallography plugin info) VMD is exiting"
      return
    }

    # Check for display transforms
    #
    # Known bug: In VMD 1.9, 'display' commands such as 'display resize' aren't logged.
    # I'm not sure how we should trace these
    if {[string match "color *" $::vmd_logfile] || [string match "display *" $::vmd_logfile]} {
      debug "Re-check background color"
      reset_colors
    }
    if {[string match "rotate *" $::vmd_logfile] || [string match "translate *" $::vmd_logfile]
        || [string match "scale *" $::vmd_logfile] || [string match "mol top *" $::vmd_logfile]
        || [string match "color *" $::vmd_logfile] || [string match "display *" $::vmd_logfile]} {
      # 
      set orientationChanged 1
      update
    }
  } elseif {"[lindex $args 0]" == "vmd_frame"} {
    # It appears like VMD calls vmd_frame for each drawing update. For example,
    # the command "rotate z by 1" will trigger vmd_frame up to 4 times if our 
    # plugin is active..
    if {$currentMol != "none"} {
     set f [molinfo $currentMol get frame]
     if {$f != $currentFrame} {
      debug "  new frame: $f"
      set currentFrame $f
      update
     }
    }
  }
}

proc ::Crystallography::on_vmd_quit { args } {
  debug "Crystallography plugin info) Got vmd_quit event"
  disable_Crystallography
}

proc ::Crystallography::reset_colors {} {
  variable crystColor
  if [display get backgroundgradient] {
    set backlight [eval vecadd [colorinfo rgb [color Display BackgroundBot]]]
  } else {
    set backlight [eval vecadd [colorinfo rgb [color Display Background]]]
  }
  if {$backlight <= 1.2} {
    debug "  background is dark"
    set crystColor white
  } else {
    debug "  background is light"
    set crystColor black
  }
}

# draw_arrow origin vector [label] [thickness]
proc ::Crystallography::draw_arrow {args} {
  variable canvasMol
  variable displaySize
  set tip_arrow_len 0.2
  set tip_label ""
  set thickness 2.

  set start [lindex $args 0]
  set vec [lindex $args 1]
  if {[llength $args] > 2} { set tip_label [lindex $args 2] }
  if {[llength $args] > 3} { set thickness [lindex $args 3] }
  set thickness_int [expr {round($thickness)}]        ;# the line drawing function is limited to integer widths
  set fontsize [expr {.5*$thickness}]

  set disp "$displaySize(x) $displaySize(y) $displaySize(z)"

  set a1start [ vecmul $start $disp ]
  set a1end [ vecadd $a1start [ vecmul $vec $disp ] ]

  set veclen [ veclength [vecsub $a1end $a1start] ]
  # Only show vector if its length exceeds a certain minimum treshold:
  if { $veclen < 0.1 } { return 0 }

  graphics $canvasMol line $a1start $a1end width $thickness_int
  
  # draw arrowhead:
  set tip_r [ vectrans [transaxis z 45] [ vecscale -$tip_arrow_len $vec ] ]
  set tip_l [ vectrans [transaxis z -45] [ vecscale -$tip_arrow_len $vec ] ]
  graphics $canvasMol line $a1end "[ vecadd $a1end [ vecmul $tip_r $disp] ]" width $thickness_int
  graphics $canvasMol line $a1end "[ vecadd $a1end [ vecmul $tip_l $disp] ]" width $thickness_int
  
  # draw label (and try to more or less center-align it):
  set dist [vecscale 0.2 [vecsub $a1end $a1start]]
  set cos_ang [expr {[vecdot "1 0 0" "$dist"] / [veclength "$dist"]}]   ;# [-1,1]
  set char_width [expr {$fontsize*0.04}]   ;# the approximate width of a single character
  set str_width [expr {$char_width * [string length $tip_label]}]
  set dx [expr {-$str_width/2. + $str_width/2*$cos_ang}] ;# subtract for approximate center-alignment
  set dist [vecadd $dist "$dx 0 0"]
  set lab_pos [vecadd $a1end $dist]
  # If label goes out of screen, fix it:
  if {[set oos [expr {[lindex $lab_pos 0] + .95*$displaySize(x)}]] < 0.} { 
      set lab_pos [vecadd $lab_pos "[expr {-$oos}] 0 0"] }
  if {[set oos [expr {[lindex $lab_pos 0] + $str_width - 0.95*$displaySize(x)}]] > 0.} { 
      set lab_pos [vecadd $lab_pos "[expr {-$oos}] 0 0"] }
  graphics $canvasMol text $lab_pos "$tip_label" thickness $fontsize size $fontsize
  # Debug: Uncomment to visualize the quality of the pseudo-center-alignment:
  #graphics $canvasMol line "$lab_pos" [vecadd "$lab_pos" "$str_width 0 0"]
  return $lab_pos
}

proc ::Crystallography::draw_CrystallographicAxes {} {
  variable unitCell
  variable currentMol
  variable crystAxesScale
  variable crystAxesLoc
  variable posLowerLeft
  variable posUpperLeft
  variable posUpperRight
  variable posLowerRight
  
  set rot [lindex [molinfo $currentMol get rotate_matrix] 0]

  set a [ vecnorm [list [lindex $unitCell 0 0] [lindex $unitCell 1 0] [lindex $unitCell 2 0]  [lindex $unitCell 3 0] ]]
  set a_x [ vecdot $a [lindex $rot 0]]
  set a_y [ vecdot $a [lindex $rot 1]]

  set b [ vecnorm [list [lindex $unitCell 0 1] [lindex $unitCell 1 1] [lindex $unitCell 2 1]  [lindex $unitCell 3 1] ]]
  set b_x [ vecdot $b [lindex $rot 0]]
  set b_y [ vecdot $b [lindex $rot 1]]

  set c [ vecnorm [list [lindex $unitCell 0 2] [lindex $unitCell 1 2] [lindex $unitCell 2 2]  [lindex $unitCell 3 2] ]]
  set c_x [ vecdot $c [lindex $rot 0]]
  set c_y [ vecdot $c [lindex $rot 1]]


  set len [expr {0.2 * $crystAxesScale / 100.}]
  set thickness [expr {2. * $crystAxesScale / 100.}]
 
  switch "$crystAxesLoc" {
    "lower left" { set origin_x $posLowerLeft(x); set origin_y $posLowerLeft(y); }
    "upper left" { set origin_x $posUpperLeft(x); set origin_y $posUpperLeft(y); }
    "upper right" { set origin_x $posUpperRight(x); set origin_y $posUpperRight(y); }
    "lower right" { set origin_x $posLowerRight(x); set origin_y $posLowerRight(y); }
    default { set origin_x 0; set origin_y 0; }
  }
  
  # if out of screen, fix
  if {[set oos [expr {$origin_x + $len*$a_x + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}] 
  } elseif {[set oos [expr {$origin_x + $len*$a_x - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }
  if {[set oos [expr {$origin_x + $len*$b_x + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}]
  } elseif {[set oos [expr {$origin_x + $len*$b_x - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }
  if {[set oos [expr {$origin_x + $len*$c_x + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}] 
  } elseif {[set oos [expr {$origin_x + $len*$c_x - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }

  if {[set oos [expr {$origin_y + $len*$a_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
  } elseif {[set oos [expr {$origin_y + $len*$a_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }
  if {[set oos [expr {$origin_y + $len*$b_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
  } elseif {[set oos [expr {$origin_y + $len*$b_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }
  if {[set oos [expr {$origin_y + $len*$c_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
  } elseif {[set oos [expr {$origin_y + $len*$c_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }

  draw_arrow "$origin_x $origin_y 1" "[expr $len*$a_x] [expr $len*$a_y] 0" "a" $thickness
  draw_arrow "$origin_x $origin_y 1" "[expr $len*$b_x] [expr $len*$b_y] 0" "b" $thickness
  draw_arrow "$origin_x $origin_y 1" "[expr $len*$c_x] [expr $len*$c_y] 0" "c" $thickness
  
}

# draw_miller_arrow $origin $vector $projection_vector [$thickness]
proc ::Crystallography::draw_miller_arrow {args} {
  variable canvasMol
  variable displaySize
  
  set thickness 2.
  set origin [lindex $args 0]
  set vec [lindex $args 1]
  set proj [lindex $args 2]
  if {[llength $args] > 3} { set thickness [lindex $args 3] }
  set thickness_int [expr {round($thickness)}]        ;# the line drawing function is limited to integer widths
  set fontsize [expr {.5*$thickness}]


  # Scale vector to integer values (e.g. [0.7 0 0.7] -> [1 0 1])
  set scale 1
  for {set j 0} {$j < 3} {incr j} {
    set vlen [expr {abs([lindex $proj $j])}]
    if { $vlen > 0.001 && $vlen < $scale } { 
      set scale $vlen
    }
  }
  set int_proj [vecscale [expr {1./$scale}] $proj]
  
  set x [lindex $int_proj 0]
  set y [lindex $int_proj 1]
  set z [lindex $int_proj 2]

  set disp "$displaySize(x) $displaySize(y) $displaySize(z)"
  
  #debug "V: $int_proj"
  # Check if the vector is (more or less) along a crystal plane 
  if { [expr {round($x*10)/10. == round($x)*1.}] &&
       [expr {round($y*10)/10. == round($y)*1.}] &&
       [expr {round($z*10)/10. == round($z)*1.}] } {
    
    # Hurray, it is! Then we convert the float coordinates into 
    # integer ones and replace minuses by overbars to make the 
    # output look like standard Miller notation.
    set x [expr {round($x)}]
    set y [expr {round($y)}]
    set z [expr {round($z)}]
    if {[set absx [expr {abs($x)}]] == $x} { set barx " " } else { set barx "_" }
    if {[set absy [expr {abs($y)}]] == $y} { set bary " " } else { set bary "_" }
    if {[set absz [expr {abs($z)}]] == $z} { set barz " " } else { set barz "_" }
   
    # Draw arrow with label:
    set txt [format "\[%d%d%d\]" $absx $absy $absz ] 
    set lab_pos [draw_arrow $origin $vec $txt $thickness]

    # Add overbars:
    set bar_pos [vecadd $lab_pos "[vecmul "0 [expr {0.052*$fontsize}] 0" $disp]"]
    graphics $canvasMol text $bar_pos " $barx$bary$barz " size $fontsize

  } else {
    
    # Otherwise, we just output the raw coordinates
    set txt [ format "(% .2f % .2f % .2f)" [lindex $proj 0] [lindex $proj 1] [lindex $proj 2] ]
    #graphics $canvasMol text [ vecmul $pos $disp ] "$txt" size [expr {.8*$fontsize}]
    draw_arrow $origin $vec $txt $thickness
  }
  # Draw fixed arrows
  #set lab_pos [vecadd $origin "[vecscale 1.2 $xvec]"]  ;# add some space
}


proc ::Crystallography::draw_ViewVectors {} {
  variable canvasMol
  variable currentMol
  variable canvasMolScale
  variable canvasMol
  variable unitCell
  variable viewVectorsScale
  variable viewVectorsLoc
  variable posLowerLeft
  variable posUpperLeft
  variable posUpperRight
  variable posLowerRight

  set len [expr {0.2 * $viewVectorsScale / 100.}]
  set thickness [expr {2. * $viewVectorsScale / 100.}]
  
  # Determine location

  set rot [molinfo $currentMol get rotate_matrix]
  switch "$viewVectorsLoc" {
    "lower left" { 
        set origin "$posLowerLeft(x) $posLowerLeft(y) 1"
        set xvec "$len 0.0 0.0"                                 ;# rightwards
        set xproj [cart2cryst [lindex $rot 0 0]]
        set yvec "0.0 $len 0.0"                                 ;# upwards
        set yproj [cart2cryst [lindex $rot 0 1]]
    }
    "upper left" { 
        set origin "$posUpperLeft(x) $posUpperLeft(y) 1"
        set xvec "$len 0.0 0.0"                                 ;# rightwards
        set xproj [cart2cryst [lindex $rot 0 0]]
        set yvec "0.0 [expr {-$len}] 0.0"                       ;# downwards 
        set yproj [cart2cryst [vecscale -1 [lindex $rot 0 1]]]
    }
    "upper right" { 
        set origin "$posUpperRight(x) $posUpperRight(y) 1";
        set xvec "[expr {-$len}] 0.0 0.0"                       ;# leftwards 
        set xproj [cart2cryst [vecscale -1 [lindex $rot 0 0]]]
        set yvec "0.0 [expr {-$len}] 0.0"                       ;# downwards 
        set yproj [cart2cryst [vecscale -1 [lindex $rot 0 1]]]
    }
    "lower right" { 
        set origin "$posLowerRight(x) $posLowerRight(y) 1" 
        set xvec "[expr {-$len}] 0.0 0.0"                       ;# leftwards 
        set xproj [cart2cryst [vecscale -1 [lindex $rot 0 0]]]
        set yvec "0.0 $len 0.0"                                 ;# upwards
        set yproj [cart2cryst [lindex $rot 0 1]]
    }
    default { set origin_x 0; set origin_y 0; }
  }
  
  # Draw arrows
  draw_miller_arrow $origin $xvec $xproj $thickness
  draw_miller_arrow $origin $yvec $yproj $thickness

}
