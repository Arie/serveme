var reservationStatusSpinning = false;

function getReservationStatus() {
  startStatusSpinner();
  $.getJSON(reservation_status_url, function(data) {
    handleReservationStatus(data.reservation);
  });
}


function handleReservationStatus(reservation) {
  switch(reservation.status) {
    case "ready":
      handleReservationReady();
      break;
    case "waiting_to_start":
      handleReservationWaitingToStart();
      break;
    case "starting":
      handleReservationStarting(reservation.status_messages);
      break;
    case "ended":
      handleReservationEnded();
      break;
  }
}

function reservationStatusField() {
  return $("#reservation_status");
}

function reservationStatusSpinner() {
  return $("#reservation_status_spinner");
}

function reservationStatusMessage() {
  return $("#reservation_status_message");
}

function handleReservationReady() {
  reservationStatusMessage().html("<i class='fa fa-check'></i>Ready");
  stopStatusSpinner();
}

function handleReservationWaitingToStart() {
  reservationStatusMessage().html("Waiting to start");
  setTimeout(getReservationStatus, 500);
}


function handleReservationEnded() {
  reservationStatusMessage().html("Ended");
  stopStatusSpinner();
}

function handleReservationStarting(status_messages) {
  reservationStatusMessage().html("Starting: " + status_messages.slice(0)[0]);
  setTimeout(getReservationStatus, 500);
}

function startStatusSpinner() {
  if(reservationStatusSpinning !== true) {
    reservationStatusSpinner().html("<i class='fa fa-spinner fa-spin reservation_status_spinner' '></i>");
  }
}

function stopStatusSpinner() {
  reservationStatusSpinning = false;
  $('.reservation_status_spinner').remove();
}

