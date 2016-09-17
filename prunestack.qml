//=============================================================================
//  PruneStack Plugin for MuseScore 2.x
//  Copyright (C) 2016 Rob Birdwell
//  BirdwellMusic.com
//=============================================================================
import QtQuick 2.1
import QtQuick.Controls 1.0
import MuseScore 1.0

MuseScore {
    version:  "1.0"
    description: "Prune Stack"
    menuPath: "Plugins.PruneStack"
    pluginType: "dialog"
    width:  380
    height: 160

    function getAllNotesInRange(noteArray) {
      
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
                        // TODO: do I/we care about grace notes in this context? RB
                        var graceChords = cursor.element.graceNotes;
                        for (var i = 0; i < graceChords.length; i++) {
                            // iterate through all grace chords
                            var notes = graceChords[i].notes;
                            for (var j = 0; j < notes.length; j++) {
                                noteArray.push(notes[j]);
                            }
                        }
                        var notes = cursor.element.notes;
                        for (var i = 0; i < notes.length; i++) {
                            var note = notes[i];
                            noteArray.push(note);
                        }
                    }
                    cursor.next();
                }
            }
        }
    }


    // TODO: re-factor as a lot of this code is shared with pruneStack()
    // NOTE: this functionality isn't working - seems to move to layer
    //       but it's not real...when saved, the notes come back to the layer they were on.  RB
    function moveToLayer()
    {
       console.log("Starting moveToLayer()");

        // Get the selected notes in the selected segment...
        var notes = new Array();
        getAllNotesInRange(notes);

        var notesToMove = new Array();
        
        var vStackHeight = parseInt(ctrlStackSize.text); 
        var vStackSelectIndicesCsv = ctrlStackLevels.text;  
        var vStackSelectIndices = vStackSelectIndicesCsv.split(",");
        var layer = parseInt(ctrlLayer.text);    

        if ( isNaN(vStackHeight) )
        {
            console.log("Invalid Stack Height Entry. Nan! Process aborted.");      
            return;
        }

        if ( isNaN(layer) || layer < 1 || layer > 4 )
        {
            console.log("Invalid Layer Entry. Nan! Process aborted.");      
            return;   
        }

        var offset = 0;            
        for (var i=0; i < notes.length; i++) {
                  
            if ( offset > (vStackHeight-1) ) {
                offset = 0;
            }
                  
            for ( var j=0; j<vStackSelectIndices.length; j++ ) {
                var parsedIndex = parseInt(vStackSelectIndices[j]);
                if ( isNaN(parsedIndex) || parsedIndex <= 0 || parsedIndex > vStackHeight ) {
                    continue;
                }

                if ( offset == (parsedIndex-1) ) { // compare to 0-based index.
                    notesToMove.push(notes[i]);
                }
            }
                  
            offset++;
        }

        if ( notesToMove.length > 0 )
        {
            curScore.startCmd();

            for ( var n=0; n < notesToMove.length; n++)
            {
                notesToMove[n].track = (layer-1);
            }

            curScore.endCmd();
      
            // refresh the current state of the layout with changes!
            curScore.doLayout();
        }
    }

    function pruneStack()
    {
        console.log("Starting pruneStack()");

        // Get the selected notes in the selected segment...
        var notes = new Array();
        getAllNotesInRange(notes);

        var notesToDelete = new Array();
        
        var vStackHeight = parseInt(ctrlStackSize.text); 
        var vStackSelectIndicesCsv = ctrlStackLevels.text;  
        var vStackSelectIndices = vStackSelectIndicesCsv.replace(" ", "").split(",");

        if ( isNaN(vStackHeight) )
        {
            console.log("Invalid Stack Height Entry. Nan! Process aborted.");      
            return;
        }

        var offset = 0;            
        for (var i=0; i < notes.length; i++) {
                  
            if ( offset > (vStackHeight-1) ) {
                offset = 0;
            }
                  
            for ( var j=0; j<vStackSelectIndices.length; j++ ) {
                var parsedIndex = parseInt(vStackSelectIndices[j]);
                if ( isNaN(parsedIndex) || parsedIndex <= 0 || parsedIndex > vStackHeight ) {
                    continue;
                }

                if ( offset == (parsedIndex-1) ) { // compare to 0-based index.
                    notesToDelete.push(notes[i]);
                }
            }
                  
            offset++;
        }

        if ( notesToDelete.length > 0 )
        {
            curScore.startCmd();

            for ( var n=0; n<notesToDelete.length; n++)
            {
                var chord = notesToDelete[n].parent;
                chord.remove(notesToDelete[n]); 
            }

            curScore.endCmd();
      
            // refresh the current state of the layout with changes!
            curScore.doLayout();
        }

      console.log("Ending pruneStack()");
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

        width: 380
        height: 160
        property alias btnPruneStack: btnPruneStack
        property alias btnMoveToLayer : btnMoveToLayer
        property alias btnClose: btnClose
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
                id: ctrlStackSizeLabel
                x: 20
                y: 20
                width: 100
                text: qsTr("Stack Size:")
                font.bold: true
                font.pointSize: 14
            }

            TextInput {
                id: ctrlStackSize
                x: 140
                y: 20
                width: 35
                height: 30
                text: qsTr("3")
                cursorVisible: true
                color: "blue" 
                font.pointSize: 14
            }

            Text {
                id: ctrlStackRangeLabel
                x: 20
                y: 50
                width: 100
                text: "Levels:"
                font.bold: true
                font.pointSize: 14
            }

            TextInput {
                id: ctrlStackLevels
                x: 140
                y: 50
                width: 100
                height: 30
                text: qsTr("2,3")
                cursorVisible: true
                color: "blue" 
                font.pointSize: 14
            }

            Text {
                id: ctrlLayerLabel
                x: 20
                y: 90
                width: 100
                text: "Layer:"
                font.bold: true
                visible: false
            }

            TextInput {
                id: ctrlLayer
                x: 140
                y: 90
                width: 100
                height: 30
                text: qsTr("2")
                cursorVisible: true
                visible: false
            }

            Button {
                id: btnPruneStack
                x: 241
                y: 20
                width: 125
                height: 35
                text: qsTr("Prune Stack")
                onClicked: { 
                    pruneStack();
                    Qt.quit();
                }
            }

            // TODO: this feature not implemented/hidden for now.
            // Ideally, we can set a selected stack of notes to another layer/track. RB
            Button {
                id: btnMoveToLayer
                x: 241
                y: 65
                width: 125
                height: 35
                text: qsTr("Move to Layer")
                enabled: false
                visible: false
                onClicked: { 
                    moveToLayer();
                    Qt.quit();
                }
            }

            Button {
                id: btnClose
                x: 241
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
                y: 90
                width: 200
                text: qsTr("Hints: bottom note is lowest in stack; comma delimit stack levels; Save your score now!")
                font.bold: true
                color: "white"
                wrapMode: Text.WordWrap
            }

        }
    }

