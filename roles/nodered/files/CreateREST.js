msg.payload = {

  name: msg.payload.name,

  address: msg.payload.address,

  body:
  {
    userCallsign: msg.payload.userCallsign,
    dateTime: msg.payload.dateTime,
    TimeObserved: msg.payload.time,
    MethodOfDetection: msg.payload.Method,
    SurveillanceType: msg.payload.SurveillanceType,
    DurationofEvent: msg.payload.Duration,
    eventScale: msg.payload.eventScale,
    type: msg.payload.type,
    Size: msg.payload.size,
    Equipment: msg.payload.equipment,
    activity: msg.payload.activity,
    importance: msg.payload.importance,
    status: msg.payload.status,
    Identification: msg.payload.Identification,
    AssessedThreats: msg.payload.AssessedThreats,
    FinalRemarks: msg.payload.FinalRemarks,
  },
}

return msg;
