# Weather and location privacy

Weather is offline until you enter a location in Settings → Dashboard. An
empty location triggers no geocoding or forecast request, including on first
boot. Clearing the location stops refreshes and discards responses from any
request that was already in flight.

When you enter a city, Hornero uses the Open-Meteo geocoding and forecast APIs
over HTTPS. When you enter coordinates, Hornero uses the Open-Meteo forecast
API over HTTPS and sends those coordinates to OpenStreetMap Nominatim over
HTTPS to display the city name. Weather does not infer your location from
your IP address.

To stop weather requests, clear the location in Settings → Dashboard. No
weather location is required to use HorneroOS.
