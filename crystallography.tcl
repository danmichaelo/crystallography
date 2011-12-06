#
# crystallography.tcl : Crystallography VMD plugin
#
#   This plugin was written primarily to make it easier to align the view direction along 
#   specific crystallographic directions. It also includes commands to convert vectors 
#   between crystallographic and cartesian coordinates, and to draw crystallographic axes 
#   arrows and view direction arrows.
#
#   For the plugin to work, the loaded molecule must contain unit cell information.
#   If VMD can not read this from your file, it can be set manually using the 
#   pbctools plugin. Note that pbctools also provide the nice command `pbc box' to draw
#   the unit cell.
#
# Author: Dan Michael O. Heggø <danmichaelo _at_ gmail.com>
#
#   I'm grateful to Cohen for the 'ruler' plugin and Liang for the 'colorscalebar' plugin,
#   whose code provided great help!
#
# Installation:
#
#   Put the crystallography folder in a folder searched by VMD, that is, a folder listed 
#   in auto_path. For instance, you may put it in ~/vmd/plugins, and add
#       set auto_path [concat $env(HOME)/vmd/plugins $auto_path] ;
#   to your ~/.vmdrc file. To add the plugin to the Plugins-menu, add the following to 
#   your ~/.vmdrc file (or just type it in VMD when needed):
#       vmd_install_extension crystallography cryst_tk "Crystallography"
#   
# Miller indices:
#
#   [uvw] denotes directions parallel to the _direct_ lattice vector $u\vec{a} + v\vec{b} + w\vec{c}$,
#   where $\vec{a}$, $\vec{b}$, $\vec{c}$ are the basis vectors of the real space lattice.
#
#   (hkl) denotes planes orthogonal to the _reciprocal_ lattice vector $h\vec{a*} + k\vec{b*} + l\vec{b3}$,
#   where $\vec{a*}$, $\vec{b*}$, $\vec{c*}$ are the basis vectors of the reciprocal space lattice.
#
#   A view can be specified either as a projection along a direct lattice vector [uvw], or as 
#   as projection along a reciprocal lattice vector [hkl]* towards a plane (hkl).
#
# Example usage:
#
#   To view along the [111] direction, type `view_along {1 1 1}` or `view_along 111`.
#   To view towards the (100) plane, type `view_towards {1 0 0}` or `view_towards 100`.
#   To show crystal axes (without using the GUI), type `crystal_axes on -position lower-left`, say. 
#   Similarly, type `view_vectors on` to show the vectors of the current viewing plane. 
#   The plugin tries to show these as properly formatted Miller indices when a crystal plane is in focus.
#   `cart2dir` transforms a vector from a cartesian basis {i,j,k} into a real space lattice basis {a,b,c}, 
#   and `dir2cart` transforms the other way around. 
#   `cart2rec` transforms a vector from a cartesian basis {i,j,k} into a reciprocal space lattice basis {a*,b*,c*}, 
#   and `dir2rec` transforms the other way around. 
#
# Known bug(s):
#
#   1. When graphic elements are drawn in the VMD window, these elements need to be 
#      redrawn when the display is altered in some way. The plugin listens to VMD events 
#      to be notified about such display changes, but VMD does not seem to inform about 
#      all such changes. Examples of events that does not seem to be broudcasted include
#       - smooth rotations: rotate [x | y | z] <angle> <increment>
#       - display resize
#
#   2. There are some drawing issues with the view vectors. The text may for instance
#      crash slightly the arrows. The problem is that VMD provides no (known) ways
#      for computing the size of text primitives added by VMD's graphics command. 
#      Also there seems to be no way to use a monospaced font(?)
#

#########################################################################################
#                                    Main commands 
#########################################################################################

#########################################
# cryst_help
#
#   Displays a command cheatsheet
#
proc cryst {} {
    puts "Commands provided by the Crystallography plugin:"
    puts "   view_along {u v w}    or    view_along uvw"
    puts "      View along the \[uvw\] axis"
    puts "   view_towards {h k l}    or    'view_along hkl'"
    puts "      View along the normal to the (hkl) plane"
    puts "   cryst_axes on|off -position lower-left|upper-left|lower-right|upper-right"
    puts "      Toggle crystallographic vectors a, b, c"
    puts "   view_vectors on|off -position lower-left|upper-left|lower-right|upper-right"
    puts "      Toggle view vectors (x and y direction in crystal coordinates)"
    puts "   cryst_debug on|off"
    puts "      Toggle debug messages"
    puts "   cryst_info"
    puts "      Print unit cell info"
    puts "   cart2dir {x y z}    and    dir2cart {X Y Z}"
    puts "      Converts a vector between cartesian and direct coordinates"
    puts "   cart2rec {x y z}    and    rec2cart {X Y Z}"
    puts "      Converts a vector between cartesian and reciprocal coordinates"
}

#########################################
# cart2dir $vec
#
#     Transforms a vector (x,y,z) from a cartesian basis (i,j,k) to a direct lattice 
#     vector basis (a,b,c) using the available unit cell information.
#
# Example:
#
#     >>> set dirvec [cart2dir {4.5 0 0}]
#
proc cart2dir {vec} {
    ::Crystallography::update
    return [::Crystallography::cart2dir $vec]
}

#########################################
# dir2cart $vec
#
#     Transforms a vector (u,v,w) from a direct lattice vector basis (a,b,c)
#     to a cartesian basis (i,j,k) using the available unit cell information.
#
# Example:
#
#     >>> set cartvec [dir2cart {1 1 1}]
#
proc dir2cart {vec} {
    ::Crystallography::update
    return [::Crystallography::dir2cart $vec]
}

#########################################
# cart2rec $vec
#
#     Transforms a vector (x,y,z) from a cartesian basis (i,j,k) to a reciprocal lattice 
#     vector basis (a*,b*,c*) using the available unit cell information.
#
# Example:
#
#     >>> set recvec [cart2rec {4.5 0 0}]
#
proc cart2rec {vec} {
    ::Crystallography::update
    return [::Crystallography::cart2rec $vec]
}

#########################################
# rec2cart $vec
#
#     Transforms a vector (u,v,w) from a reciprocal lattice vector basis (a*,b*,c*)
#     to a cartesian basis (i,j,k) using the available unit cell information.
#
# Example:
#
#     >>> set cartvec [rec2cart {1 1 1}]
#
proc rec2cart {vec} {
    ::Crystallography::update
    return [::Crystallography::rec2cart $vec]
}

#########################################
# view_along $projection_vector [$upward_vector]
#
# Aligns the z axis (the `view axis') with $projection_vector, where $projection_vector 
# is a direct lattice vector [uvw].
#
# If only the projection vector is specified, there will still remain freedom for rotation
# about the z axis. To completely specify the view, a vector to be aligned with
# the upwards direction (y direction) can be specified as the second argument.
#
# If $projection_vector and $upward_vector are not orthogonal, the 
# $upward_vector is made orthogonal to $projection_vector. This is done
# automatically when using the command line interface, but a notification
# is displayed when using the GUI.
#
# [*] Currently the GUI has to be used to select the correct molecule if 
#     more molecules are loaded.
#
# Example:
#     view_along {0 0 1} {1 0 0}
#     view_along 001 100
#
proc view_along {args} {
    if {[llength $args] == 0} {
        puts "usage: view_along projection_vector \[upwards_vector\]"
        puts "example: view_along {1 1 1}"
        return
    }
    ::Crystallography::update
    if {[llength $args] == 1} {
        ::Crystallography::set_view_direction [lindex $args 0] -projalong "uvw"
    } elseif {[llength $args] == 2} {
        ::Crystallography::set_view_direction [lindex $args 0] -upvec [lindex $args 1] -projalong "uvw"
    }
}

#########################################
# view_towards $projection_vector [$upward_vector]
#
# Aligns the z axis (the `view axis') with $projection_vector, where $projection_vector 
# is a reciprocal lattice vector [hkl]* normal to a crystal plane (hkl).
#
# If only the projection vector is specified, there will still remain freedom for rotation
# about the z axis. To completely specify the view, a vector to be aligned with
# the upwards direction (y direction) can be specified as the second argument.
#
# If $projection_vector and $upward_vector are not orthogonal, the 
# $upward_vector is made orthogonal to $projection_vector. This is done
# automatically when using the command line interface, but a notification
# is displayed when using the GUI.
#
# [*] Currently the GUI has to be used to select the correct molecule if 
#     more molecules are loaded.
#
# Example:
#     view_towards {0 0 1} {1 0 0}
#     view_towards 001 100
#
proc view_towards {args} {
    if {[llength $args] == 0} {
        puts "usage: view_towards projection_vector [upwards_vector]"
        puts "example: view_towards {1 1 1}"
        return
    }
    ::Crystallography::update
    if {[llength $args] == 1} {
        ::Crystallography::set_view_direction [lindex $args 0] -projalong "hkl"
    } elseif {[llength $args] == 2} {
        ::Crystallography::set_view_direction [lindex $args 0] -upvec [lindex $args 1] -projalong "hkl"
    }
}

##########################################
# cryst_axes on|off
# OPTIONS:
#   -position lower-left|upper-left|lower-right|upper-right
# Toggles the display of the crystal axes. Currently, the GUI provides 
# some more options than the command line interface.
# 
proc cryst_axes {args} {
    if {[llength $args] == 0} {
        puts "usage: cryst_axes on/off [-position lower-left|upper-left|lower-right|upper-right]"
        puts "example: cryst_axes on"
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
# cryst_debug on|off
#
# Toggles the display of debug messages. 
# 
proc cryst_debug {args} {
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


#########################################
# cryst_info
#
#     Prints out the direct and reciprocal lattice vectors in a format 
#     suitable for copying into python, matlab, and the like.
#
# Example:
proc cryst_info {} {
    #variable recUnitCell
    puts "Direct lattice vectors:"
    set a [lrange [lindex $::Crystallography::unitCell 0] 0 2]
    set b [lrange [lindex $::Crystallography::unitCell 1] 0 2]
    set c [lrange [lindex $::Crystallography::unitCell 2] 0 2]
    puts [format "  a1 = \[% .8f, % .8f, % .8f\]" [lindex $a 0] [lindex $a 1] [lindex $a 2]]
    puts [format "  a2 = \[% .8f, % .8f, % .8f\]" [lindex $b 0] [lindex $b 1] [lindex $b 2]]
    puts [format "  a3 = \[% .8f, % .8f, % .8f\]" [lindex $c 0] [lindex $c 1] [lindex $c 2]]

    puts "Reciprocal lattice vectors:"
    set aa [lrange [lindex $::Crystallography::recUnitCell 0] 0 2]
    set bb [lrange [lindex $::Crystallography::recUnitCell 1] 0 2]
    set cc [lrange [lindex $::Crystallography::recUnitCell 2] 0 2]
    puts [format "  b1 = \[% .8f, % .8f, % .8f\]" [lindex $aa 0] [lindex $aa 1] [lindex $aa 2]]
    puts [format "  b2 = \[% .8f, % .8f, % .8f\]" [lindex $bb 0] [lindex $bb 1] [lindex $bb 2]]
    puts [format "  b3 = \[% .8f, % .8f, % .8f\]" [lindex $cc 0] [lindex $cc 1] [lindex $cc 2]]
}

##########################################
# check_norms
#
# Checks if the current unit vectors are orthogonal. This function is for internal
# testing of the plugin.
# 
proc check_norm {} {
    # WARNING: using molinfo 0 instead of molinfo $currentMol !!
    set rot [lindex [molinfo 0 get rotate_matrix] 0]
    
    set dotxy [vecdot [lindex $rot 0] [lindex $rot 1]]
    set dotxz [vecdot [lindex $rot 0] [lindex $rot 2]]
    set dotyz [vecdot [lindex $rot 1] [lindex $rot 2]]
    if {$dotxy == 0.0 && $dotxz == 0. && $dotyz == 0.} {
        puts "Coordinate vectors are orthogonal"
    } else {
        puts "Coordinate vectors are not orthogonal"
        puts "dot(x,y) = $dotxy"
        puts "dot(x,z) = $dotxz"
        puts "dot(y,z) = $dotyz"    
    }
    
    for {set i 0} {$i < 3} {incr i} {
        puts "Vector length: [veclength [lindex $rot $i]]"
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

#########################################################################################
#                               Crystallography "class"  
#########################################################################################

package provide crystallography 1.1

namespace eval ::Crystallography:: {

    puts "DEBUG: init Crystallography"

    set listenersEnabled 0     ;# whether the event listeners (Tcl "tracers") are activated or not
    #set crystallographyState off

    set darkColor gray
    set lightColor white

    set crystColor $darkColor   ;# use a dark foreground color? 
    set canvasMol -1                 ;# mol in which the drawing is done
    set canvasMolScale 1.            ;# scale of the canvas mol
    array set displaySize {x 1 y 1 z 1}    ;# size of window
    set latticeParam { 0 0 0 0 0 0 }
    set unitCellVol 0                ;# unit cell volume in Ang**3
    set unitCellValid 0			     ;# molecule has unit cell data?
    set pbcChanged 0                 ;# track unitcell
    set orientationChanged 0         ;# track orientation
    set printDebug 0                 ;# print debug messages or not
    set currentFrame -1		         ;# 
    set progressIndicatorFound 0     ;# has ProgressIndicator timeline been found?
    set progressIndicatorMargin 0.3  ;# margin for ProgressIndicator timeline
    set currentMol [molinfo top]     ;# mol of study
    if { $currentMol == -1 } { set currentMol "none" }
    set previousMol $currentMol
    trace add variable ::Crystallography::currentMol write ::Crystallography::currentMolChanged

    # 4x4 transformation matrix in cartesian coordinates:
    set unitCell {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}

    # ... and the inverse:
    set unitCellInv {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}  

    # 4x4 transformation matrix in reciprocal coordinates:
    set recUnitCell {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}

    # ... and the inverse:
    set recUnitCellInv {{ 0 0 0 0 } { 0 0 0 0 } { 0 0 0 0 } { 0 0 0 1 }}

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

#
# If a float <f> is close enough to a reference value <ref>, this
# function will set the float equal to the reference value.
# This is useful to remove some numerical noise.
proc ::Crystallography::fix_float {f ref} {
    set tol 1e-5
    if {abs($f-$ref)<$tol} {
        return $ref
    }
    return $f
}

proc ::Crystallography::read_pbc {} {
    variable unitCell
    variable recUnitCell
    variable recUnitCellInv
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

    # a1 vector:
    lset unitCell 0 0 $a 
    lset unitCell 1 0 0 
    lset unitCell 2 0 0 
    set a1 [list [lindex $unitCell 0 0] [lindex $unitCell 1 0] [lindex $unitCell 2 0]]

    # a2 vector:
    lset unitCell 0 1 [fix_float [expr {$b*cos($gamma)}] 0]
    lset unitCell 1 1 [fix_float [expr {$b*sin($gamma)}] 0]
    lset unitCell 2 1 0 
    set a2 [list [lindex $unitCell 0 1] [lindex $unitCell 1 1] [lindex $unitCell 2 1]]

    # a3 vector:
    lset unitCell 0 2 [fix_float [expr {$c*cos($beta)}] 0] 
    lset unitCell 1 2 [fix_float [expr {$c*cos($alpha)-cos($beta)*cos($gamma)/sin($gamma)}] 0] 
    lset unitCell 2 2 [fix_float [expr {$unitCellVol/($a*$b*sin($gamma))} ] 0] 
    set a3 [list [lindex $unitCell 0 2] [lindex $unitCell 1 2] [lindex $unitCell 2 2]]

    set unitCellInv [ matrix3to4 [ mat3_inverse [ matrix4to3 $unitCell ] ] ]

	# Find inverse volume
	set iv [expr {1./$unitCellVol}]

    # a* vector:
    set b1 [vecscale $iv [veccross $a2 $a3]]
    set b2 [vecscale $iv [veccross $a3 $a1]]
    set b3 [vecscale $iv [veccross $a1 $a2]]
    lappend b1 0
    lappend b2 0
    lappend b3 0
    set recUnitCell [transtranspose [list $b1 $b2 $b3 {0 0 0 1}]]

    set recUnitCellInv [ matrix3to4 [ mat3_inverse [ matrix4to3 $recUnitCell ] ] ]

    return 1

}

proc ::Crystallography::vecproj { u v } {
    if {abs([vecdot $u $v]) < 1e-16} {
        debug "Warning: ::Crystallography::vecproj: Vectors u anv v are orthogonal"
    }
    return [vecscale [expr [vecdot $v $u] / [vecdot $u $u]] $u]
}

# Transforms a vector (u,v,w) from a direct lattice vector basis (a,b,c)
# to a cartesian basis (x,y,z)
proc ::Crystallography::dir2cart { vec } {
    variable unitCell
    variable currentMol
    if {$currentMol == -1} return
    return [vecnorm [coordtrans $unitCell $vec ]]
}

# Transforms a vector from a cartesian basis (x,y,z)
# to a direct lattice vector basis (a,b,c)
proc ::Crystallography::cart2dir { vec } {
    variable unitCellInv
    variable currentMol
    if {$currentMol == -1} return
    return [ coordtrans $unitCellInv $vec ]
}

# Transforms a vector (h,k,l) from a reciprocal lattice vector basis (a*,b*,c*)
# to a cartesian basis (x,y,z)
proc ::Crystallography::rec2cart { vec } {
    variable recUnitCell
    variable currentMol
    if {$currentMol == -1} return
    return [vecnorm [coordtrans $recUnitCell $vec ]]
}

# Transforms a vector from a cartesian basis (x,y,z)
# to a reciprocal lattice vector basis (a*,b*,c*)
proc ::Crystallography::cart2rec { vec } {
    variable recUnitCellInv
    variable currentMol
    if {$currentMol == -1} return
    return [ coordtrans $recUnitCellInv $vec ]
}

# To specify the view uniquely, two orthogonal vectors are needed. 
# To view along the 110 vector (z vector), with the 001 vector pointing upwards on the screen (y direction):
# set_view_direction {1 1 0} {0 0 1}
# To view along the 110 (z vector) and automaticly calculate y (non-uniquely!):
# set_view_direction {1 1 0}
# Short-hand notation is supported for vectors consisting of only positive single-numerals:
# set_view_direction 111
proc ::Crystallography::set_view_direction { args } {
    variable unitCell
    variable unitCellInv
    variable currentMol
    variable orientationChanged
    if {$currentMol == "none"} {
        puts "Error: No molecule selected"
        return
    }
    
    set p [ lindex [ pbc get -molid $currentMol ] 0] 
    if {"[lindex $p 0]" == "0"} {
        puts "Error: Unit cell data missing"
        return
    }

    # Parse options
    set projvec [lindex $args 0]
    set upvec {0 0 1}               ;# default upwards vector. Perhaps the default could be chosen slightly more intelligibly?
    set upvecDefault 1
    set projalong "uvw"
    for { set argnum 1 } { $argnum < [llength $args] } { incr argnum } {
        set arg [ lindex $args $argnum ]
        set val [ lindex $args [expr $argnum + 1]]
        switch -- $arg {
            "-upvec"      { set upvec $val; set upvecDefault 0; incr argnum }
            "-projalong"  { set projalong $val; incr argnum }
            default { error "error: crystallogrpahy: unknown option: $arg" }
        }
    }
    if { [llength $projvec] == 1 && [string length $projvec] == 3} {
        set projvec [list [string index $projvec 0] [string index $projvec 1] [string index $projvec 2]]
    } elseif { [llength $projvec] != 3 } {
        puts "Error: projection vector must be either a string of length 3 or a list of length 3"
        return
    }
    if { [llength $upvec] == 1 && [string length $upvec] == 3} {
        set upvec [list [string index $upvec 0] [string index $upvec 1] [string index $upvec 2]]
    } elseif { [llength $upvec] != 3 } {
        puts "Error: upwards vector must be either a string of length 3 or a list of length 3"
        return
    }

    # set z vector (projection vector)
    if {$projvec == [veczero]} { puts "ERROR: You would see very little along the zero vector (or maybe everything?)"; return; }
    if {$upvec == [veczero]} { puts "ERROR: You would see very little along the zero vector (or maybe everything?)"; return; }
    if { "$projalong" == "uvw" } {
	    set z_vec [ dir2cart $projvec ]
	    set y_vec [ rec2cart $upvec ]
	} elseif { "$projalong" == "hkl" } {
	    set z_vec [ rec2cart $projvec ]	
	    set y_vec [ dir2cart $upvec ]	
	} else {
		# ERROR: Unknown
		puts "Error: Unknown proj $projalong"
		return
	}

    # Check if z and y are orthogonal
    set y_ok 1
    if { abs([vecdot $z_vec $y_vec]) > 1e-2} {
        debug "y and z are not orthogonal"
        if {$upvecDefault == 0} {
	        # TODO: implement a non-GUI alternative? something like gets stdin answer?
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

############################################################
#
# ::Crystallography::get_view_vector $vec $basis
# 
#     Returns the direct (if $basis = "dir") or reciprocal (if $basis = "rec") lattice vector
#     of the direction $vec, where $vec is either "x", "y" or "z"      
#
# Example: 
#     # returns the current projection vector in direct lattice vector basis (a,b,c):
#     ::Crystallography::get_view_vector "z" "dir" 
#
proc ::Crystallography::get_view_vector {vec basis} {
	variable currentMol
    set rot [molinfo $currentMol get rotate_matrix]

    if { "$basis" == "dir" } {
		switch -- $vec {
			"x"	{ set proj [cart2dir [lindex $rot 0 0]] }
			"y"	{ set proj [cart2dir [lindex $rot 0 1]] }
			"z"	{ set proj [cart2dir [lindex $rot 0 2]] }
			default { error "error: get_view_vector: vector must be x, y or z" }
		}
	} elseif { "$basis" == "rec" } {
		switch -- $vec {
			"x"	{ set proj [cart2rec [lindex $rot 0 0]] }
			"y"	{ set proj [cart2rec [lindex $rot 0 1]] }
			"z"	{ set proj [cart2rec [lindex $rot 0 2]] }
			default { error "error: get_view_vector: vector must be x, y or z" }
		}
	} else {
	    print "ERROR: unknown basis"
	    return
	}
	
	return [scale_vec_to_integer $proj] 

}

proc ::Crystallography::equalLists {x1 x2} {

    set treshold 0.01   ;# Make this smaller if you want to work with vectors like [100 0 0]

    if {[llength $x1] != [llength $x2]} { return 0; }
    for {set i 0} {$i<[llength $x1]} {incr i} {
        if {abs([lindex $x1 $i] - [lindex $x2 $i]) > $treshold} { return 0; }
    }
    return 1;    
}

proc ::Crystallography::roundLists {x} {
    set t {}
    foreach i $x {
        lappend t [expr {round($i)}]
    }
    return $t
}


#########################################################################################
#                                   Drawing section
#########################################################################################

proc ::Crystallography::currentMolChanged {args} {
    variable currentMol
    variable previousMol
    if {$previousMol != $currentMol} {
        debug ">>>>>>>>>>>> Current mol changed from $previousMol to $currentMol"
        set previousMol $currentMol
        drawSettingsChanged
    }  
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
    debug ">>>>>>>>>>>> Creating canvas"

    # Create canvas mol for drawing:
    set canvasMol [mol new]
    mol rename $canvasMol "Crystallography Canvas"

    # Fixes the drawing canvas "molecule". This makes the canvas more stable, but if 
    # the molecule get out of view for some reason, it's harder to get it back into view.
    # This requires some testing.
    # mol fix $canvasMol

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
        set crystColor $::Crystallography::lightColor
    } else {
        debug "  background is light"
        set crystColor $::Crystallography::darkColor
    }
}

############################################################
#
# ::Crystallography::draw_3d_arrow $start $direction [OPTIONS...]
#
# Draws a 3D arrow from the point $start in the direction $direction.
# Both $start and $direction are specified as lists of length 3.
#
# OPTIONS:
#   -radius $radius
#		arrow radius, in units of the arrow length
#   -tiplength $len
#		length of the arrow tip (the cone), in units of the arrow length
#   -resolution $res
#
proc ::Crystallography::draw_3d_arrow {args} {
    variable canvasMol
    set rad 0.05
    set tiplen 0.3
    set res 10

    # Parse arguments:
    set start [lindex $args 0]
    set vec [lindex $args 1]
    for { set argnum 2 } { $argnum < [llength $args] } { incr argnum } {
        set arg [ lindex $args $argnum ]
        set val [ lindex $args [expr $argnum + 1]]
        switch -- $arg {
            "-tiplength"   { set tiplen $val; incr argnum }
            "-radius"      { set rad $val; incr argnum }
            "-resolution"  { set res $val; incr argnum }
            default { error "error: crystallography: unknown option: $arg" }
        }
    }

    set end [vecadd $start $vec]
    set middle [vecadd $start [vecscale [expr {1.0-$tiplen}] [vecsub $end $start]]]
    set rad [expr {$rad*[veclength $vec]}]

    #puts "start: $start, middle: $middle, end: $end"
    graphics $canvasMol cylinder $start $middle radius $rad resolution $res filled yes
    graphics $canvasMol cone $middle $end radius [expr $rad * 2.3] resolution $res

}


# draw_2d_arrow origin vector [label] [thickness]
proc ::Crystallography::draw_2d_arrow {args} {
    variable canvasMol
    set tiplen 0.2
    set thickness 2.

    set start [lindex $args 0]
    set vec [lindex $args 1]
    for { set argnum 2 } { $argnum < [llength $args] } { incr argnum } {
        set arg [ lindex $args $argnum ]
        set val [ lindex $args [expr $argnum + 1]]
        switch -- $arg {
            "-tiplength"   { set tiplen $val; incr argnum }
            "-thickness"   { set thickness $val; incr argnum }
            default { error "error: crystallography: unknown option: $arg" }
        }
    }
    set thickness_int [expr {round($thickness)}]        ;# the line drawing function is limited to integer widths

    set end [vecadd $start $vec]
    set middle [vecadd $start [vecscale [expr {1.0-$tiplen}] [vecsub $end $start]]]

    # draw arrowline:
    graphics $canvasMol line $start $end width $thickness_int

    # draw arrowhead:
    set tip_r [ vectrans [transaxis z 45] [ vecscale -$tiplen $vec ] ]
    set tip_l [ vectrans [transaxis z -45] [ vecscale -$tiplen $vec ] ]
    graphics $canvasMol line $end [vecadd $end $tip_r] width $thickness_int
    graphics $canvasMol line $end [vecadd $end $tip_l] width $thickness_int
}

############################################################
#
# ::Crystallography::draw_arrow_label $start $direction $label [OPTIONS...]
# 
# Draws a textlabel $label for an arrow pointing from $start in the direction $direction.
# Both $start and $direction are specified as lists of length 3.
#
# OPTIONS:
#   -fontsize $fontsize
#   -distance $dist
#		distance from the arrow, in units of the arrow length
#
proc ::Crystallography::draw_arrow_label {args} {
    variable canvasMol
    variable displaySize
    set dist 0.25               ;# distance from arrowhead to label
    set fontsize 1.0
    set char_width 0.03			;# the empirical character width "constant" at unit fontsize 

    # Parse arguments:
    set start [lindex $args 0]
    set vec [lindex $args 1]
    set label [lindex $args 2]
    for { set argnum 3 } { $argnum < [llength $args] } { incr argnum } {
        set arg [ lindex $args $argnum ]
        set val [ lindex $args [expr $argnum + 1]]
        switch -- $arg {
            "-fontsize"    { set fontsize $val; incr argnum }
            "-distance"    { set dist $val; incr argnum }
            default { error "error: crystallography: unknown option: $arg" }
        }
    }

    set end [vecadd $start $vec]

    # draw label (and try to more or less center-align it):

    set dist [vecscale $dist [lreplace $vec 2 2 0.0]] ;# x,y direction only, drop z direction

    set cos_ang [expr {[vecdot "1 0 0" "$dist"] / [veclength "$dist"]}]   ;# [-1,1]
    set char_width [expr {$displaySize(y)*$fontsize*$char_width}]
    set str_width [expr {$char_width * [string length $label] }]
    set dx [expr {-$str_width/2. + $str_width/2*$cos_ang}] ;# subtract for approximate center-alignment
    set dist [vecadd $dist "$dx 0 0"]
    set lab_pos [vecadd $end $dist]
    # If label goes out of screen, fix it:
    if {[set oos [expr {[lindex $lab_pos 0] + .95*$displaySize(x)}]] < 0.} { 
        set lab_pos [vecadd $lab_pos "[expr {-$oos}] 0 0"] }
    if {[set oos [expr {[lindex $lab_pos 0] + $str_width - 0.95*$displaySize(x)}]] > 0.} { 
        set lab_pos [vecadd $lab_pos "[expr {-$oos}] 0 0"] }
    graphics $canvasMol text $lab_pos "$label" thickness $fontsize size $fontsize

    # Debug: Uncomment to visualize the quality of the pseudo-center-alignment:
    #graphics $canvasMol line "$lab_pos" [vecadd "$lab_pos" "$str_width 0 0"]

    return $lab_pos
}

############################################################
#
# ::Crystallography::scale_vec_to_integer $vec
# 
# Scales a vector consisting of 3 floats to (smallest) 3 integers
# Examples:
#   scale_vec_to_integer {0.7 0.7 0.7} returns {1 1 1} 
#   scale_vec_to_integer {-0.07312614470720291 0.0 0.05484461039304733} returns {-4 0 3} 
#
proc ::Crystallography::scale_vec_to_integer {vec} {
    
    set maxint 100   ;# make this larger if you want to work with vectors like [200 0 0]
    
    set scale 1.e6
    for {set j 0} {$j < 3} {incr j} {
        set vlen [expr {abs([lindex $vec $j])}]
        if { $vlen > 0.001 && $vlen < $scale } { 
            set scale $vlen
        }
    }
    debug "Vec is $vec. Scale is $scale" 
    for {set i 1} {$i <= $maxint} {incr i} {
        set int_vec [vecscale [expr {$i/$scale}] $vec]
        set rounded [roundLists $int_vec]
        debug " Attempt $i of $maxint: $rounded"
        if {[equalLists $rounded $int_vec] == 1} {
            debug "   attempt successful"
            return $rounded
        }
    }
    # Should we return something?
    return {}
}

############################################################
#
# ::Crystallography::draw_arrow_miller_label $start $direction $projection_vector [OPTIONS...]
# 
# Adds a label based on $projection_vector for an arrow pointing from $start in the 
# direction $direction. 
# Both $start and $direction are specified as lists of length 3.
#
# OPTIONS:
#   -fontsize $fontsize
#
proc ::Crystallography::draw_arrow_miller_label {args} {
    variable canvasMol
    variable displaySize
    set char_width 0.03
    set thickness 2.
    set fontsize 1.0

    # Parse arguments:
    set origin [lindex $args 0]
    set vec [lindex $args 1]
    set proj [lindex $args 2]
    for { set argnum 3 } { $argnum < [llength $args] } { incr argnum } {
        set arg [ lindex $args $argnum ]
        set val [ lindex $args [expr $argnum + 1]]
        switch -- $arg {
            "-fontsize"    { set fontsize $val; incr argnum }
            default { error "error: crystallography: unknown option: $arg" }
        }
    }
    
    # Scale vector to integer values (e.g. [0.7 0 0.7] -> [1 0 1])
    set int_proj [scale_vec_to_integer $proj]
    if {[llength $int_proj] == 0} {
        set int_proj $proj     ;# means that we failed to obtain one
    }
    #set int_proj [vecscale [expr {1./$scale}] $proj]

    set x [lindex $int_proj 0]
    set y [lindex $int_proj 1]
    set z [lindex $int_proj 2]

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
        set lab_pos [draw_arrow_label $origin $vec $txt -fontsize $fontsize]

        # Add overbars: (for some reason it seems like it's displaySize(y) that determines the font size)
        set char_width [expr {$displaySize(y)*$fontsize*$char_width}]
        set bar_pos [vecadd $lab_pos "[expr {-0.01*$char_width}] [expr {1.7*$char_width}] 0"]
        graphics $canvasMol text $bar_pos " $barx$bary$barz " size $fontsize

    } else {

        # Otherwise, we just output the raw coordinates
        set txt [ format "(% .2f % .2f % .2f)" [lindex $proj 0] [lindex $proj 1] [lindex $proj 2] ]
        #graphics $canvasMol text [ vecmul $pos $disp ] "$txt" size [expr {.8*$fontsize}]
        draw_arrow_label $origin $vec $txt -fontsize $fontsize
    }
    # Draw fixed arrows
    #set lab_pos [vecadd $origin "[vecscale 1.2 $xvec]"]  ;# add some space
}

proc ::Crystallography::checkForProgressIndicator {} {
  #variable posLowerLeft
  #variable posLowerRight
  #variable progressIndicatorMargin
  variable progressIndicatorFound
  if {![catch {package present ProgressIndicator}]} {
    if {$::ProgressIndicator::timeline_on && !$progressIndicatorFound} {
      puts "Crystallography: Addition of statusindicator plugin detected. Let's adjust"
      #set posLowerLeft(y) [expr {$posLowerLeft(y) - $progressIndicatorMargin}]
      #set posLowerRight(y) [expr {$posLowerRight(y) - $progressIndicatorMargin}]
      set progressIndicatorFound 1
    } elseif {!$::ProgressIndicator::timeline_on && $progressIndicatorFound} {
      puts "Crystallography: Removal of statusindicator plugin detected. Let's adjust"
      #set posLowerLeft(y) [expr {$posLowerLeft(y) + $progressIndicatorMargin}]
      #set posLowerRight(y) [expr {$posLowerRight(y) + $progressIndicatorMargin}]
      set progressIndicatorFound 0
    }
  }
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
    variable displaySize
    variable progressIndicatorFound

    set rot [lindex [molinfo $currentMol get rotate_matrix] 0]

    set a [ vecnorm [list [lindex $unitCell 0 0] [lindex $unitCell 1 0] [lindex $unitCell 2 0]  [lindex $unitCell 3 0] ]]
    set a_rot [vectrans $rot $a]
    set a_x [lindex $a_rot 0]
    set a_y [lindex $a_rot 1]
    set a_z [lindex $a_rot 2]

    set b [ vecnorm [list [lindex $unitCell 0 1] [lindex $unitCell 1 1] [lindex $unitCell 2 1]  [lindex $unitCell 3 1] ]]
    set b_rot [vectrans $rot $b]
    set b_x [lindex $b_rot 0]
    set b_y [lindex $b_rot 1]
    set b_z [lindex $b_rot 2]

    set c [ vecnorm [list [lindex $unitCell 0 2] [lindex $unitCell 1 2] [lindex $unitCell 2 2]  [lindex $unitCell 3 2] ]]
    set c_rot [vectrans $rot $c]
    set c_x [lindex $c_rot 0]
    set c_y [lindex $c_rot 1]
    set c_z [lindex $c_rot 2]


    set len [expr {0.2 * $crystAxesScale / 100.}]
    #set thickness [expr {2. * $crystAxesScale / 100.}]
    set fontsize [expr {$crystAxesScale / 100.}]
    
    switch "$crystAxesLoc" {
        "lower left" { set origin_x $posLowerLeft(x); set origin_y $posLowerLeft(y); }
        "upper left" { set origin_x $posUpperLeft(x); set origin_y $posUpperLeft(y); }
        "upper right" { set origin_x $posUpperRight(x); set origin_y $posUpperRight(y); }
        "lower right" { set origin_x $posLowerRight(x); set origin_y $posLowerRight(y); }
        default { set origin_x 0; set origin_y 0; }
    }

    # if out of screen, fix
    puts "$origin_x, $len, $a_x"
    set f [expr {$displaySize(y)/$displaySize(x)}]
    if {[set oos [expr {$origin_x + $len*$a_x*$f + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}] 
    } elseif {[set oos [expr {$origin_x + $len*$a_x*$f - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }
    if {[set oos [expr {$origin_x + $len*$b_x*$f + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}]
    } elseif {[set oos [expr {$origin_x + $len*$b_x*$f - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }
    if {[set oos [expr {$origin_x + $len*$c_x*$f + 0.90}]] < 0.} { set origin_x [expr {$origin_x - $oos}] 
    } elseif {[set oos [expr {$origin_x + $len*$c_x*$f - 0.90}]] > 0.} { set origin_x [expr {$origin_x - $oos}] }

    if {[set oos [expr {$origin_y + $len*$a_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
    } elseif {[set oos [expr {$origin_y + $len*$a_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }
    if {[set oos [expr {$origin_y + $len*$b_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
    } elseif {[set oos [expr {$origin_y + $len*$b_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }
    if {[set oos [expr {$origin_y + $len*$c_y + 0.90}]] < 0.} { set origin_y [expr {$origin_y - $oos}] 
    } elseif {[set oos [expr {$origin_y + $len*$c_y - 0.90}]] > 0.} { set origin_y [expr {$origin_y - $oos}] }

    # quick and dirty:
    checkForProgressIndicator
    if {$progressIndicatorFound} { set origin_y [expr {$origin_y + 0.2}] }
    
    #draw_2d_arrow "$origin_x $origin_y 0" "[expr $len*$a_x] [expr $len*$a_y] 0" "a" $thickness
    #draw_2d_arrow "$origin_x $origin_y 0" "[expr $len*$b_x] [expr $len*$b_y] 0" "b" $thickness
    #draw_2d_arrow "$origin_x $origin_y 0" "[expr $len*$c_x] [expr $len*$c_y] 0" "c" $thickness

    set disp "$displaySize(x) $displaySize(y) $displaySize(z)"

    set origin [vecmul "$origin_x $origin_y 1" $disp]
    set len [expr {$len * $displaySize(y)}]
    # subtract vector length from z origin to make sure we don't get clipped by near clip:
    lset origin 2 [expr {[lindex $origin 2]-$len}]  
    
    # from length-4 to length-3 vectors, and scale to fixed size
    set a [vecscale $len [lrange $a_rot 0 2]]
    set b [vecscale $len [lrange $b_rot 0 2]]
    set c [vecscale $len [lrange $c_rot 0 2]]

    draw_3d_arrow $origin $a
    draw_3d_arrow $origin $b
    draw_3d_arrow $origin $c

    # Draw labels for vectors whose projection in the xy-plane is longer than a minimum treshold:
    if {[veclength [lrange $a 0 1]] > 0.1} { draw_arrow_label $origin $a "a" -fontsize $fontsize }
    if {[veclength [lrange $b 0 1]] > 0.1} { draw_arrow_label $origin $b "b" -fontsize $fontsize }
    if {[veclength [lrange $c 0 1]] > 0.1} { draw_arrow_label $origin $c "c" -fontsize $fontsize }

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
    variable displaySize
    variable progressIndicatorFound
    
    # quick and dirty fix for moving the origin if the statusindicator is enabled too:
    checkForProgressIndicator
    set lowerLeftY $posLowerLeft(y)
    set lowerRightY $posLowerRight(y)
    if {$progressIndicatorFound} { 
        set lowerLeftY [expr {$lowerLeftY + 0.15}]
        set lowerRightY [expr {$lowerRightY + 0.15}] 
    }

    set len [expr {0.2 * $viewVectorsScale / 100.}]
    set thickness [expr {3. * $viewVectorsScale / 100.}]
    set fontsize [expr {2. * $viewVectorsScale / 100.}]

    # Determine location

    set rot [molinfo $currentMol get rotate_matrix]
    switch "$viewVectorsLoc" {
        "lower left" { 
            set origin "$posLowerLeft(x) $lowerLeftY 1"
            set xvec "1.0 0.0 0.0"                                 ;# rightwards
            set xproj [cart2dir [lindex $rot 0 0]]
            set yvec "0.0 1.0 0.0"                                 ;# upwards
            set yproj [cart2dir [lindex $rot 0 1]]
        }
        "upper left" { 
            set origin "$posUpperLeft(x) $posUpperLeft(y) 1"
            set xvec "1.0 0.0 0.0"                                 ;# rightwards
            set xproj [cart2dir [lindex $rot 0 0]]
            set yvec "0.0 -1.0 0.0"                                ;# downwards 
            set yproj [cart2dir [vecscale -1 [lindex $rot 0 1]]]
        }
        "upper right" { 
            set origin "$posUpperRight(x) $posUpperRight(y) 1";
            set xvec "-1.0 0.0 0.0"                                ;# leftwards 
            set xproj [cart2dir [vecscale -1 [lindex $rot 0 0]]]
            set yvec "0.0 -1.0 0.0"                                ;# downwards 
            set yproj [cart2dir [vecscale -1 [lindex $rot 0 1]]]
        }
        "lower right" { 
            set origin "$posLowerRight(x) $lowerRightY 1" 
            set xvec "-1.0 0.0 0.0"                                ;# leftwards 
            set xproj [cart2dir [vecscale -1 [lindex $rot 0 0]]]
            set yvec "0.0 1.0 0.0"                                 ;# upwards
            set yproj [cart2dir [lindex $rot 0 1]]
        }
        default { set origin "0 0"; }
    }

    # Draw arrows
    set disp "$displaySize(x) $displaySize(y) $displaySize(z)"
    set len [expr {$len * $displaySize(y)}]

    set origin [vecmul $origin $disp]
    set xvec [vecscale $len $xvec]
    set yvec [vecscale $len $yvec]

    draw_2d_arrow $origin $xvec -thickness $thickness
    draw_2d_arrow $origin $yvec -thickness $thickness

    draw_arrow_miller_label $origin $xvec $xproj -fontsize $fontsize
    draw_arrow_miller_label $origin $yvec $yproj -fontsize $fontsize

}
