# gcp-streaming-chargingstations
Simple tutorial with ELT using Pub/Sub, DataFlow, BigQuery and GeoViz




```
INSERT INTO `.data_prod.ChargingStations` SELECT id, name, street, town as city, lat, lng, provider FROM `.data_raw.stations`
```




https://bigquerygeoviz.appspot.com/

```
SELECT *, ST_GEOGPOINT(lng, lat) as loc FROM `.data_prod.ChargersAvailability` 
```
