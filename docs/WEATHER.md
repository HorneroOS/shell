# Weather and location privacy

Weather is offline until you enter a location in Settings → Dashboard. An
empty location triggers no geocoding or forecast request, including on first
boot. Clearing the location stops refreshes and discards responses from any
request that was already in flight.

When you enter a city, Hornero uses the Open-Meteo geocoding and forecast APIs
over HTTPS. When you enter coordinates, Hornero uses the Open-Meteo forecast
API over HTTPS and sends those coordinates to OpenStreetMap Nominatim over
HTTPS to display the city name. The Nominatim request identifies HorneroOS
Shell with an application-specific `User-Agent`. The weather view credits
Open-Meteo and displays OpenStreetMap contributor attribution linking to its
copyright page; the Control Center also explains the location data flow.
Weather does not infer your location from your IP address.

Nominatim is a community service with a usage policy. This client makes a
reverse-geocoding request only for an explicitly entered coordinate location,
reuses the city name in memory for the current shell process, and does not
send periodic reverse-geocoding requests. The service may still rate-limit or
decline requests; the weather view falls back to an unknown city label.

To stop weather requests, clear the location in Settings → Dashboard. No
weather location is required to use HorneroOS.
