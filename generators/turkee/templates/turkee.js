// Javascript referenced from the rturk example.

// Initializes a mechanical turk form and disables the form button
//   until the user has accepted the turk task.
function mturk_form_init()
{
    document.getElementById('assignmentId').value = gup('assignmentId');

    //
    // Check if the worker is PREVIEWING the HIT or if they've ACCEPTED the HIT
    //
    if (gup('assignmentId') == "ASSIGNMENT_ID_NOT_AVAILABLE")
    {
      // If we're previewing, disable the button and give it a helpful message
      document.getElementById('submitButton').disabled = true;
      document.getElementById('submitButton').value = "You must ACCEPT the HIT before you can submit the results.";
    } else {
        var form = document.getElementById('mturk_form');
        if (document.referrer && ( document.referrer.indexOf('workersandbox') != -1) ) {
            form.action = "https://workersandbox.mturk.com/mturk/externalSubmit";
        }
    }
}
