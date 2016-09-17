//=============================================================================
//  PruneStack Plugin for MuseScore 2.x
//  This script Copyright (C) 2016 Rob Birdwell and BirdwellMusic.com
//  Full credit to the MuseScore team and all numerous other plugin developers.  
//  Portions of this script were adapted from the colornotes.qml, walk.qml and
//  other scripts by Werner Schweer, et al. 
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2
//  as published by the Free Software Foundation and appearing in
//  the file LICENCE.GPL
//=============================================================================
import QtQuick 2.1
import QtQuick.Controls 1.0
import MuseScore 1.0

MuseScore {
    version:  "1.0"
    description: "Selectively prune notes from a chord based on their vertical stack level in the chord."
    menuPath: "Plugins.Prune Stack"
    pluginType: "dialog"
    width:  380
    height: 160

    function getAllChordsInRange(chordArray) {
      
        var cursor = curScore.newCursor();
        cursor.rewind(1);
        var startStaff;
        var endStaff;
        var endTick;

        if (!cursor.segment) { // no selection
            console.log("Hey there, you must select a region of notes on a single staff.");
            return;
        } 
            
        startStaff = cursor.staffIdx;
        cursor.rewind(2);
        if (cursor.tick == 0) {
            // this happens when the selection includes
            // the last measure of the score.
            // rewind(2) goes behind the last segment (where
            // there's none) and sets tick=0
            endTick = curScore.lastSegment.tick + 1;
        } else {
            endTick = cursor.tick;
        }
            
        endStaff = cursor.staffIdx;
            
        if ( startStaff != endStaff ) {
            console.log("Hey there, you must select a single staff only!");
            return;
        }

        for (var staff = startStaff; staff <= endStaff; staff++) {
            for (var voice = 0; voice < 4; voice++) {
                cursor.rewind(1); // sets voice to 0
                cursor.voice = voice; //voice has to be set after goTo
                cursor.staffIdx = staff;
                   
                while (cursor.segment && (cursor.tick < endTick)) {
                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        var graceChords = cursor.element.graceNotes;
                        for (var i = 0; i < graceChords.length; i++) {
                              chordArray.push(graceChords[i]);
                        }
                       
                        // the chord of the notes...
                        chordArray.push(cursor.element);
 
                    }
                    cursor.next();
                }
            }
        }
    }

    function pruneStack()
    {
        console.log("Starting pruneStack()");
        ctrlMessageLabel.text = "";

        // Get the selected chords in the selected segment...
        var chords = new Array();
        getAllChordsInRange(chords);

        var notesToDelete = new Array();

        var levels = new Array();
        if ( ctrlCheckBoxLevel8.checked ) {
            levels.push(8);
        }
        if ( ctrlCheckBoxLevel7.checked ) {
            levels.push(7);
        }
        if ( ctrlCheckBoxLevel6.checked ) {
            levels.push(6);
        }
        if ( ctrlCheckBoxLevel5.checked ) {
            levels.push(5);
        }
        if ( ctrlCheckBoxLevel4.checked ) {
            levels.push(4);
        }
        if ( ctrlCheckBoxLevel3.checked ) {
            levels.push(3);
        }
        if ( ctrlCheckBoxLevel2.checked ) {
            levels.push(2);
        }
        if ( ctrlCheckBoxLevel1.checked ) {
            levels.push(1);
        }
           
        console.log("# of chords: " + chords.length);
        console.log("# of levels to prune: " + levels.length);

        // NOTE: it's a known issue if we delete every note in a the chord (cause an exception)
        // so if this is detected, we won't actually prune...
        var emptyChordPotential = false;

        for (var c=0; c < chords.length; c++) {
            var notesInChord = chords[c].notes.length;

            console.log("# of notes in chord # " + (c+1) + ":" + notesInChord);

            var notesQueuedToDeleteInChord = 0;

            for ( var n=0; n < chords[c].notes.length; n++ ) {
                  for ( var j=0; j < levels.length; j++ ) {
                     if ( (levels[j]-1) != n ) {
                       //console.log("Skipped note #" + (n+1) + " at level #" + levels[j] + " in chord #" + (c+1));
                       continue;
                     }

                     notesToDelete.push(chords[c].notes[n]);
                     notesQueuedToDeleteInChord++;
                     
                     console.log("Added a note to delete at level #" + levels[j] + " in chord #" + (c+1) + " - # notes in chord: " + notesInChord );

                     if ( notesQueuedToDeleteInChord >= notesInChord ) {
                        console.log("Empty chord potential detected at level #" + levels[j] + " in chord #" + (c+1));
                        emptyChordPotential = true;
                     }
                  }
             }
        }

        var pruned = false;
        var whyNoPrune = "";

        if ( notesToDelete.length > 0 )
        {
            curScore.startCmd();

            if ( emptyChordPotential == false ) {
                  for ( var n = 0; n < notesToDelete.length; n++) {
                      var chord = notesToDelete[n].parent;
                      chord.remove(notesToDelete[n]); 
                      pruned = true;
                  }
            }
            else {
                  console.log("No notes pruned as the requested prune levels would create an empty chord, which is not allowed!");
                  whyNoPrune = qsTr("Can't do - would create an empty chord! Try reducing levels.");
                  pruned = false;
            }

            curScore.endCmd();
        }

      // if something pruned, refresh the current state of the layout with changes!
      if ( pruned ) {
         curScore.doLayout();
      } else {
         if ( whyNoPrune.length > 0 ) {
            ctrlMessageLabel.text = whyNoPrune;
         } else {
            ctrlMessageLabel.text = qsTr("Nothing pruned! Select the levels that match your chords stacks.");
         } 
     }

      console.log("Ending pruneStack()");

      return pruned;
    }

    onRun: {
        console.log("PruneStack script starting...");
      
        if (typeof curScore === 'undefined') {
            console.log("PruneStack exiting without processing - no current score!");
            Qt.quit();
        }
    }

    Rectangle {
        property alias mouseArea: mouseArea
        property alias btnPruneStack: btnPruneStack
        property alias btnClose: btnClose
        property alias ctrlHintLabel : ctrlHintLabel
        width: 380
        height: 160
       
	   color: "grey"
        }

        MouseArea {
            id: mouseArea
            anchors.rightMargin: 0
            anchors.bottomMargin: 0
            anchors.leftMargin: 0
            anchors.topMargin: 0
            anchors.fill: parent

            Text {
                id: ctrlStackRangeLabel
                x: 15
                y: 15
                width: 100
                text: "Levels:"
            }

            Column {
                  x: 80
                  y: 15
                  CheckBox {
                        id: ctrlCheckBoxLevel4
                        text: qsTr("4")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel3
                        text: qsTr("3")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel2
                        text: qsTr("2")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel1
                        text: qsTr("1")
                  }
            }

            Column {
                  x: 125
                  y: 15
                  CheckBox {
                        id: ctrlCheckBoxLevel8
                        text: qsTr("8")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel7
                        text: qsTr("7")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel6
                        text: qsTr("6")
                  }
                  CheckBox {
                        id: ctrlCheckBoxLevel5
                        text: qsTr("5")
                  }
            }

            Button {
                id: btnPruneStack
                x: 240
                y: 15
                width: 125
                height: 35
                text: qsTr("Prune Stack")
                onClicked: { 
                    if ( pruneStack() ) {
                        Qt.quit();
                    }
                }
            }

            Text {
                id: ctrlMessageLabel
                x: 240
                y: 55
                width: 150
                text: qsTr("")
                font.italic: true
                color: "red"
                wrapMode: Text.WordWrap
                font.pointSize: 6
            }


            Button {
                id: btnClose
                x: 240
                y: 105
                width: 125
                height: 35
                text: qsTr("Close")
                onClicked: {
                    console.log("PruneStack closed.");
                    Qt.quit();
                }
            }

            Text {
                id: ctrlHintLabel
                x: 20
                y: 100
                width: 200
                text: qsTr("Hints: check the levels you want to prune. Notes not in level are skipped; Save your score now!")
                font.italic: true
                color: "white"
                wrapMode: Text.WordWrap
                font.pointSize: 6
            }

        }
    }
