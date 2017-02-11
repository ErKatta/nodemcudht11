uart.setup(0,115200,8,0,1)
-- Global configuration
mqttBrokerHost="192.168.1.18"
mqttBrokerPort=1883
sensorDataTopic="temphum"
sensorsCommandTopic="sensors"
dataRetrivalInterval=600000 --10 minutes
accessPointName="INSERT_HERE_AP_NAME"
accessPointPassword="INSERT_HERE_AP_PASSWORD"

wifi.setmode(wifi.STATION)
wifi.sta.setip({
  ip = "192.168.1.20",
  netmask = "255.255.255.0",
  gateway = "192.168.1.1"
})
wifi.sta.config(accessPointName,accessPointPassword)


--register callback
wifi.sta.eventMonReg(wifi.STA_IDLE, function() print("STATION_IDLE") end)
wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() print("STATION_CONNECTING") end)
wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function() print("STATION_WRONG_PASSWORD") end)
wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() print("STATION_NO_AP_FOUND") end)
wifi.sta.eventMonReg(wifi.STA_FAIL, function() print("STATION_CONNECT_FAIL") end)

--register callback: use previous state
wifi.sta.eventMonReg(wifi.STA_CONNECTING, function(previous_State)
if(previous_State==wifi.STA_GOTIP) then
  print("Station lost connection with access point\n\tAttempting to reconnect...")
  if m ~= nil then
    m:close()
  end
else
  print("STATION_CONNECTING")
end
end)

wifi.sta.eventMonReg(wifi.STA_GOTIP, function(previous_state)
print(wifi.sta.getip())
doStart()
end
)
wifi.sta.eventMonStart()

function doStart()
-- init mqtt client without logins, keepalive timer 120s
m = mqtt.Client("clientid", 120)
m:connect(mqttBrokerHost, mqttBrokerPort, 0,
function()
  print("Connected to MQTT broker")
  m:subscribe(sensorsCommandTopic,0,
  function(client)
    print("Succesfuly subscribed!")
    m:on("message",
    function(client, topic, data)
      print(topic .. ":" )
      if data ~= nil and topic == "sensors" then
        if data == "sendData" then
          sendData("CLIENT_REQUEST")
        end
      end
    end
    )
  end
  )
  end,
  function(client, reason)
    print("Connection failed! Reason: "..reason)
    m:close()
  end
  )

  tmr.alarm(2, dataRetrivalInterval, 1,
  function()
    sendData()
  end
  )

end

function getTemp()
  status, Temperature, Humidity, TemperatureDec, HumidityDec = dht.read(4)
  if status == dht.OK then
    print ("Temperature: "..Temperature)
    print ("Humidity: "..Humidity)
  elseif status == dht.ERROR_CHECKSUM then
    print( "DHT Checksum error." )
  elseif status == dht.ERROR_TIMEOUT then
    print( "DHT timed out." )
  end
end

function sendData(triggerCause)
  local trigger = nil
  if triggerCause == nil then
    trigger = "SCHEDULER"
  else
    trigger = triggerCause
  end
  getTemp()
  print("Sending data to MQTT")
  m:publish(sensorDataTopic,"{\"temperature\":"..Temperature..",\"humidity\":"..Humidity..",\"trigger\":\""..trigger.."\"}",0,0,
  function(client)
    print("Data has been sent!")
  end
  )
end

