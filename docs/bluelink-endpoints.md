# Bluelink US endpoints seen in MyHyundai 5.4.5

Captured from the MyHyundai app (Nov 2026). Values are redacted; only shapes are kept.
All take the BetterBlueKit login token in an `access_token` header. `orderInfo` was verified to accept BetterBlueKit's client id and to ignore `nadid`.

## POST /ac/v2/co/auth/v2/refreshToken → 200

```json
{
 "query": null,
 "body": {
  "refresh_token": "<redacted>"
 },
 "response": {
  "access_token": "<redacted>",
  "refresh_token": "<redacted>",
  "expires_in": "1799",
  "username": "<redacted>"
 }
}
```

## GET /ac/v2/enrollment/features/user/get → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "driverIndex": 1,
  "roles": [
   {
    "roleCode": "OWN",
    "roleName": "<redacted>"
   },
   "\u20262 items"
  ],
  "featureDetails": [
   {
    "hataFeatureName": "<redacted>",
    "featureName": "<redacted>",
    "hataCategoryName": "<redacted>",
    "featureStatus": "ON",
    "featureId": "1"
   },
   "\u2026100 items"
  ],
  "responseHeaderMap": {}
 }
}
```

## POST /ac/v2/notification/push/registration → 200

```json
{
 "query": null,
 "body": {
  "deviceToken": "<redacted>",
  "keepMeLogin": "<redacted>",
  "osVersion": "27.2",
  "deviceId": "<redacted>",
  "appId": "com.hyundaiusa.bluelink2",
  "osType": "IOS",
  "appType": "MyHyundai",
  "deviceName": "<redacted>",
  "actionType": "REGISTER",
  "deviceModel": "iPhone",
  "pushNotificationStatus": "true",
  "appVersion": "5.4.5",
  "timeOfRegistration": "20261111212048"
 },
 "response": {}
}
```

## GET /ac/v2/rc/ev/getrescharge → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "reservStartTime": {
   "timeSection": 1,
   "time": "0900"
  },
  "offpeakPowerFlag": 0,
  "reservEndTime": {
   "timeSection": 0,
   "time": "0500"
  },
  "reservFlag": 0
 }
}
```

## GET /ac/v2/ss/ntc/release/notes → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "releaseNotes": [
   {
    "android": [
     {
      "releaseNotes": "\u2022 Enhanced the Home screen with more veh\u2026",
      "releaseDate": "2026-10-15 18:30:00",
      "appVersionNo": "5.4.5"
     },
     "\u20263 items"
    ],
    "ios": [
     {
      "releaseNotes": "\u2022 Enhanced the Home screen with more veh\u2026",
      "releaseDate": "2026-10-15 18:30:00",
      "appVersionNo": "5.4.5"
     },
     "\u20263 items"
    ]
   },
   "\u20261 items"
  ]
 }
}
```

## GET /ac/v2/ca/enrollments → 404

```json
{
 "query": null,
 "body": null,
 "response": {
  "errorTrace": {
   "resultData": {
    "message": "Enrollment Details not found"
   }
  },
  "errorMessage": "Enrollment Details not found",
  "errorCode": 404
 }
}
```

## GET /ac/v2/ss/ntc/details → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "statusCodeStr": "RESPONSE_CODE_SUCCESS",
  "ntcDtailList": [
   {
    "readStatus": "N",
    "optional": "{&#34;msgType&#34;:&#34;SVM&#34;,&#34;cu\u2026",
    "id": "<redacted>",
    "title": "Surround View Monitor",
    "message": "Your request for Surround View Monitor i\u2026",
    "category": "Activity",
    "addedOn": "2026-11-11 20:17:13"
   },
   "\u202632 items"
  ],
  "status": "0",
  "statusCode": "1000"
 }
}
```

## GET /ac/v2/alerts/valet/report → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "session_list": null,
  "valetParkingStatus": "INACTIVE"
 }
}
```

## POST /ac/v2/msa/iac/serviceInfo → 200

```json
{
 "query": null,
 "body": {
  "vehicleInfo": {
   "modelCode": "NE1",
   "modelYear": "2026",
   "vin": "<redacted>",
   "brand": "H"
  },
  "profileInfo": {
   "profileId": "<redacted>",
   "profileIndex": "<redacted>",
   "profileName": "<redacted>"
  }
 },
 "response": {
  "errorCaseId": "",
  "code": 0,
  "icpServiceData": {
   "usrInfo": {
    "subscriptionInfo": true,
    "cardRegisterInfo": true,
    "cpLinkInfo": true
   }
  },
  "iacServiceInd": {
   "pncMenuInd": "Y",
   "testVehicleInd": "Y",
   "chargingStationSearchInd": "Y",
   "inAppChargingInd": "Y",
   "routePlanningInd": "Y",
   "chargingStartInd": "Y"
  },
  "icpSubscriptInfo": [
   {
    "subscriptionCost": 0.0,
    "subscriptionStatCd": "0",
    "subscriptionName": "<redacted>",
    "subscriptionEndDt": "",
    "subscriptionStartDt": "20260510"
   },
   "\u20261 items"
  ],
  "errorCode": 0,
  "tncFlag": 1,
  "vendorNum": 1047,
  "errorMsg": "Success"
 }
}
```

## GET /ac/v2/ct/user/profilesettings/get → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "calendarSetting": [
   {
    "calendarSync": "No"
   },
   "\u20261 items"
  ],
  "picturesettings": [
   {
    "rolecode": "SD",
    "loginid": "<redacted>",
    "binary": "/9j/4AAQSkZJRgABAQAA2ADYAAD/4QCARXhpZgAA\u2026"
   },
   "\u20262 items"
  ]
 }
}
```

## GET /ac/v2/ps/ms/status → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "state": "<redacted>",
  "status": "deactive"
 }
}
```

## POST /v2/ac/dk2/vehicleDKDetails → 200

```json
{
 "query": null,
 "body": {
  "carId": "<redacted>",
  "brandCd": "H",
  "userId": "<redacted>",
  "interfaceCode": "APPS07"
 },
 "response": {
  "rspMessage": "Success",
  "rspCode": "0000",
  "ownerKeyInformation": {
   "notAfter": "99991231235959.000",
   "profileInfo": {
    "profileName": "<redacted>",
    "profileId": "<redacted>",
    "phoneNum": "<redacted>"
   },
   "accessProfile": {
    "standard": "0"
   },
   "id": "<redacted>",
   "keyType": "<redacted>",
   "friendlyName": "<redacted>",
   "notBefore": "20210101000000.000",
   "status": "ACTIVE"
  },
  "vehicleDigitalKeyInformation": {
   "notAfter": "99991231235959.000",
   "profileInfo": {
    "profileName": "<redacted>",
    "profileId": "<redacted>",
    "phoneNum": "<redacted>"
   },
   "accessProfile": {
    "standard": "0"
   },
   "id": "<redacted>",
   "keyType": "<redacted>",
   "friendlyName": "<redacted>",
   "notBefore": "20210101000000.000",
   "status": "ACTIVE"
  },
  "sharedDigitalKeyInformation": [
   {
    "notAfter": "99991231235959.000",
    "profileInfo": {},
    "accessProfile": {
     "standard": "0"
    },
    "id": "<redacted>",
    "keyType": "<redacted>",
    "friendlyName": "<redacted>",
    "notBefore": "20260510183038.000",
    "status": "ACTIVE"
   },
   "\u20262 items"
  ],
  "digitalKeySharePossibility": "<redacted>",
  "nfc": "DK2PU",
  "vehicleId": "<redacted>",
  "interfaceCode": "APPS07"
 }
}
```

## POST /v2/ac/oauth/pintoken/refresh → 200

```json
{
 "query": null,
 "body": {
  "refresh_token": "<redacted>"
 },
 "response": {
  "access_token": "<redacted>",
  "refresh_token": "<redacted>",
  "expires_in": "1799",
  "username": "<redacted>"
 }
}
```

## POST /ac/v2/alerts/valet/activate → 200

```json
{
 "query": null,
 "body": {},
 "response": {
  "valetParkingActivate": "Success"
 }
}
```

## POST /ac/v2/alerts/valet/deactivate → 200

```json
{
 "query": null,
 "body": {},
 "response": null
}
```

## POST /ac/v2/msa/iac/chargingStatus → 200

```json
{
 "query": null,
 "body": {
  "genType": "3",
  "paymentId": "<redacted>",
  "needBWData": true,
  "evStatus": {
   "timeDiff": 0,
   "batteryDisChargePlugin": 0,
   "batteryStatus": 47,
   "remainTimeUnit": 1,
   "batteryCharge": true,
   "valueDiff": 0,
   "batteryPlugin": 2,
   "disChargeRemaintime": 0,
   "chargePortDoorOpen": 1,
   "pluginVoltage": 240,
   "dischargingLimit": 20,
   "remainTimeValue": 1560,
   "batteryPrecondition": 0,
   "realTimePower": 1.3,
   "drvDistance": [
    {
     "evModeRangeValue": 145,
     "totalRangeUnit": 3,
     "evModeRangeUnit": 3,
     "totalRangeValue": 145,
     "gasModeRangeUnit": 0
    },
    "\u20261 items"
   ],
   "totalRangeStr": "145 mi",
   "targetSOClist": [
    {
     "targetSOClevel": 80,
     "plugType": 0
    },
    "\u20262 items"
   ],
   "remainChargeTimeInSecond": 93600,
   "batteryDisCharge": false,
   "batteryStndChrgPower": 1.3,
   "gasRangeStr": "0 mi",
   "evRangeStr": "145 mi"
  },
  "vin": "<redacted>",
  "needToRefresh": false
 },
 "response": {
  "resultDatetime": "20261112032205",
  "pncInfo": {
   "emaId": "<redacted>",
   "pcId": "<redacted>",
   "pncStatus": "active"
  },
  "resultCode": 0,
  "evStatus": {
   "remainTime2": {
    "etc3": {
     "unit": 0,
     "value": 155.0
    },
    "etc2": {
     "unit": 0,
     "value": 1530.0
    },
    "atc": {
     "unit": 1,
     "value": 1560.0
    },
    "etc1": {
     "unit": 0,
     "value": 15.0
    }
   },
   "batteryPlugin": 2,
   "batteryStndChrgPower": 1.3,
   "batteryCharge": true,
   "batteryStatus": 47,
   "batteryPrecondition": false,
   "batteryDisChargePlugin": 0,
   "remainTime": {
    "unit": 1,
    "value": 1560.0
   },
   "drvDistance": [
    {
     "unit": 3,
     "type": 2,
     "value": 144.779848
    },
    "\u20261 it
```

## GET /ac/v2/msa/iac/preference/provider → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "providerListGis": [
   {
    "code": "2581",
    "name": "<redacted>",
    "displayOrder": 1
   },
   "\u20267 items"
  ],
  "providerListEvs": [
   {
    "code": "chargepoint",
    "name": "<redacted>",
    "displayOrder": 1
   },
   "\u20268 items"
  ]
 }
}
```

## POST /ac/v2/msa/iac/chargingStation/list → 200

```json
{
 "query": null,
 "body": {
  "radius": 5,
  "radiusUnit": "Mile",
  "brand": "Hyundai",
  "country": "US",
  "coordinate": {
   "lat": "<redacted>",
   "lon": "<redacted>"
  }
 },
 "response": {
  "chargingStations": [
   {
    "capabilities": [
     "ISO15118_CAPABLE",
     "\u20262 items"
    ],
    "chargingPower": 250.0,
    "coordinates": {
     "guidance": {
      "lon": "<redacted>",
      "lat": "<redacted>"
     },
     "center": {
      "lon": "<redacted>",
      "lat": "<redacted>"
     }
    },
    "chargingPowerUnit": "Kw",
    "id": "<redacted>",
    "chargingSpeed": "Rapid",
    "languageResources": [
     {
      "data": {
       "address": "<redacted>",
       "name": "<redacted>",
       "providers": "\u2026"
      },
      "language": "en"
     },
     "\u20261 items"
    ],
    "parcelId": "<redacted>",
    "status": [
     {
      "numberOfDisabledConnectors": 0,
      "numberOfAvailableConnectors": 6,
      "numberOfOccupiedConnectors": 2,
      "numberOfConnectors": 8,
      "chargingSpeed": "Rapid",
      "numberOfErrorConnectors": 0
     },
     "\u20261 items"
    ]
   },
   "\u202646 items"
  ]
 }
}
```

## POST /ac/v2/poi/get → 200

```json
{
 "query": null,
 "body": {
  "showFavorites": "Y",
  "username": "<redacted>",
  "vin": "<redacted>"
 },
 "response": {
  "actionType": null,
  "vin": "<redacted>",
  "userName": "<redacted>",
  "poiInfoList": [
   {
    "zip": null,
    "note": null,
    "googlerefid": null,
    "sendToCarDateTime": null,
    "src": "HERE",
    "placeid": "IAC_863331",
    "coord": {
     "alt": 0.0,
     "lon": "<redacted>",
     "type": 0,
     "lat": "<redacted>"
    },
    "phone": "<redacted>",
    "attrib": null,
    "name": "<redacted>",
    "poiId": "5464790",
    "lang": 0,
    "addr": "<redacted>",
    "isFavorite": "1"
   },
   "\u20265 items"
  ]
 }
}
```

## GET /ac/v2/ev/rc/getalarmset → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "alarmTime": 0
 }
}
```

## POST /ac/v2/msa/iac/chargingStatusCB → 200

```json
{
 "query": null,
 "body": {
  "needToRefresh": false,
  "vin": "<redacted>",
  "paymentId": "<redacted>",
  "evStatus": {
   "totalRangeStr": "145 mi",
   "drvDistance": [
    {
     "evModeRangeValue": 145,
     "totalRangeUnit": 3,
     "evModeRangeUnit": 3,
     "gasModeRangeUnit": 0,
     "totalRangeValue": 145
    },
    "\u20261 items"
   ],
   "disChargeRemaintime": 0,
   "batteryCharge": true,
   "batteryDisCharge": false,
   "realTimePower": 1.3,
   "valueDiff": 0,
   "batteryStndChrgPower": 1.3,
   "batteryPlugin": 2,
   "evRangeStr": "145 mi",
   "batteryDisChargePlugin": 0,
   "batteryPrecondition": 0,
   "remainTimeValue": 1560,
   "targetSOClist": [
    {
     "targetSOClevel": 80,
     "plugType": 0
    },
    "\u20262 items"
   ],
   "batteryStatus": 47,
   "remainChargeTimeInSecond": 93600,
   "gasRangeStr": "0 mi",
   "timeDiff": 0,
   "chargePortDoorOpen": 1,
   "remainTimeUnit": 1,
   "dischargingLimit": 20,
   "pluginVoltage": 240
  },
  "genType": "3",
  "needBWData": true
 },
 "response": {
  "resultDatetime": "20261112032205",
  "pncInfo": {
   "emaId": "<redacted>",
   "pcId": "<redacted>",
   "pncStatus": "active"
  },
  "resultCode": 2,
  "evStatus": {
   "remainTime2": {
    "etc3": {
     "unit": 0,
     "value": 155.0
    },
    "etc2": {
     "unit": 0,
     "value": 1530.0
    },
    "atc": {
     "unit": 1,
     "value": 1560.0
    },
    "etc1": {
     "unit": 0,
     "value": 15.0
    }
   },
   "batteryPlugin": 2,
   "batteryStndChrgPower": 1.3,
   "batteryCharge": true,
   "batteryStatus": 47,
   "batteryPrecondition": false,
   "batteryDisChargePlugin": 0,
   "remainTime": {
    "unit": 1,
    "value": 1560.0
   },
   "drvDistance": [
    {
     "unit": 3,
     "type": 2,
     "value": 144.779848
    },
    "\u20261 it
```

## POST /ac/v2/ts/ev/rbc → 200

```json
{
 "query": null,
 "body": {
  "batteryConditioning": 1
 },
 "response": null
}
```

## GET /ac/v2/rmt/getRunningStatus → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "nextPollingInterval": "5",
  "tid": "<redacted>",
  "status": "PENDING"
 }
}
```

## POST /ac/v2/msa/iac/orderInfo → 200

```json
{
 "query": null,
 "body": {
  "endDate": "20261113",
  "profileId": "<redacted>",
  "brandIndicator": "H",
  "startDate": "20251112"
 },
 "response": {
  "errorCaseId": "",
  "code": 0,
  "resultPrice": 315.58,
  "resultData": [
   {
    "addrLocal": "<redacted>",
    "merchantErr": "",
    "ordStatCd": "SUCCESS",
    "totalPrice": 9.59,
    "totalEnergy": 21.79,
    "discountPrice": 0.0,
    "ordQty": 21.79,
    "tid": "<redacted>",
    "trId": "<uuid>",
    "unitAmt": 0.0,
    "brndNm": "Hyundai",
    "ordNm": "[Charging Station] USMBML5685541 - USMBM\u2026",
    "addrStreet": "<redacted>",
    "stopDateTime": "2026-11-08T01:41:36Z",
    "ordDate": "20261108",
    "vhclId": "<redacted>",
    "ordNo": "<redacted>",
    "price": 9.59,
    "last4Creditcard": "<redacted>",
    "resTstz": "2026-11-08 07:41:47:161",
    "pointUseBlc": 0.0,
    "useYn": "N",
    "curr": "USD",
    "taxAmt": 0.0,
    "ordPayId": "<uuid>",
    "hpayYn": "Y",
    "payCardId": "<uuid>",
    "confirmYn": "N",
    "appCategory": "Charging",
    "membId": "<redacted>",
    "taxIncYn": "N",
    "notiYn": "N",
    "addrCity": "<redacted>",
    "merchantNm": "ChargePoint",
    "postNo": "<redacted>",
    "confirmNo": "<redacted>",
    "startDateTime": "2026-11-08T01:32:41Z",
    "ordAmt": 0.0,
    "pointPrice": 0.0,
    "dsctAmt": 0.0
   },
   "\u202621 items"
  ],
  "resultCode": 0,
  "resultEnergy": 639.487,
  "resultPointBlc": 0.0
 }
}
```

## GET /ac/v2/ts/alerts/maintenance/evTripDetails → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "tripdetails": [
   {
    "distance": 0,
    "odometer": {
     "value": 7949.945
    },
    "accessories": 30,
    "totalused": 314,
    "realtotalpwrcsp": 0,
    "regen": 179,
    "avgspeed": {
     "unit": 1,
     "value": 14.0
    },
    "maxspeed": {
     "unit": 1,
     "value": 39.0
    },
    "climate": 20,
    "drivetrain": 264,
    "startdate": "2026-11-11 14:38:35.0",
    "mileagetime": {
     "unit": 3,
     "value": 163.0
    },
    "duration": {
     "unit": 3,
     "value": 182
    },
    "batterycare": 0
   },
   "\u20264 items"
  ]
 }
}
```

## POST /ac/v2/ev/reserv/socset → 204

```json
{
 "query": null,
 "body": {
  "targetSOClist": [
   {
    "targetSOClevel": 100,
    "plugType": 0
   },
   "\u20262 items"
  ]
 },
 "response": null
}
```

## POST /ac/v2/rc/ev/reschargeset → 204

```json
{
 "query": null,
 "body": {
  "reservStartTime": {
   "time": "0900",
   "timeSection": 1
  },
  "reservFlag": 1,
  "offpeakPowerFlag": 2,
  "reservEndTime": {
   "time": "0600",
   "timeSection": 0
  }
 },
 "response": null
}
```

## GET /ac/v2/ts/alerts/maintenance/getDrivingHabits → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "vehicledrivinghabits": [],
  "drivinghabits": [
   {
    "drivingtypeid": "<redacted>",
    "drivingtypedescription": "<redacted>"
   },
   "\u202610 items"
  ],
  "modelinfo": [
   {
    "turboind": false,
    "modelid": 52374,
    "createddate": "2025-08-07 15:47:28.43",
    "modelname": "<redacted>",
    "bluelink": 3,
    "body": "3.8",
    "wifihotspotoption": 1,
    "trim": "ADRIATIC BLUE",
    "engine": "1975 cc DOHC 4 cyl",
    "createdby": "Initial",
    "modelnumber": "K4RAT",
    "modlBluelinkEnabled": "0",
    "updateddate": "2025-08-07 15:47:28.43",
    "modelyear": "2026"
   },
   "\u20261 items"
  ]
 }
}
```

## GET /ac/v2/dealer/preferred → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "zip": "<redacted>",
  "dealerWebsite": "<redacted>",
  "dealerName": "<redacted>",
  "dealerCode": "<redacted>",
  "address2": "<redacted>",
  "city": "<redacted>",
  "address1": "<redacted>",
  "serviceUrl": "<redacted>",
  "phones": [
   {
    "number": "<number>",
    "type": "WORK",
    "ordinal": 0
   },
   "\u20261 items"
  ],
  "lon": "<redacted>",
  "ioniqCertified": "true",
  "state": "<redacted>",
  "email": "<redacted>",
  "lat": "<redacted>",
  "preferred": "Y"
 }
}
```

## GET /ac/v2/dealer/contactinfo → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "ioniqCertified": ""
 }
}
```

## POST /v2/ac/oauth/token/sso → 200

```json
{
 "query": null,
 "body": {},
 "response": {
  "ref_id": "18",
  "sso_token": "<redacted>",
  "cwp_reroute_url": "https://owners.hyundaiusa.com/bin/common\u2026",
  "vin": "<redacted>",
  "expires_in": "1000",
  "username": "<redacted>"
 }
}
```

## GET /ac/v2/mvr/dates → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "loginId": "<redacted>",
  "vin": "<redacted>",
  "regId": "<redacted>",
  "signalHistoryDetails": [
   {
    "odometer": "<redacted>",
    "signalDate": "08-NOV-26 05:31:11",
    "tid": "<redacted>"
   },
   "\u20266 items"
  ]
 }
}
```

## GET /ac/v2/mvr/info → 200

```json
{
 "query": null,
 "body": null,
 "response": {
  "mvrUrl": "",
  "scoreDateUTC": "",
  "odometer": "<redacted>",
  "vin": "<redacted>",
  "tid": "<redacted>",
  "mvrDate": "20261108053111 US/Central",
  "ubiScore": 0,
  "subSystemDetails": [
   {
    "statIconAltText": "SYSTEM IS NORMAL. NO ACTION IS REQUIRED",
    "dtcSubSystem": "Anti-Lock Braking System",
    "statusIconRefId": "ICON002",
    "dtcSystem": "SAFETY",
    "status": "GREEN"
   },
   "\u20266 items"
  ]
 }
}
```

## POST /ac/v2/ct/request/v2/login → 200

```json
{
 "query": null,
 "body": {
  "username": "<redacted>",
  "password": "<redacted>"
 },
 "response": {
  "access_token": "<redacted>",
  "refresh_token": "<redacted>",
  "password_token": "<redacted>",
  "expires_in": "1799",
  "username": "<redacted>"
 }
}
```

## POST /v2/ac/oauth/token → 200

```json
{
 "query": null,
 "body": {
  "password": "<redacted>",
  "username": "<redacted>"
 },
 "response": {
  "access_token": "<redacted>",
  "refresh_token": "<redacted>",
  "expires_in": "1799",
  "username": "<redacted>"
 }
}
```

