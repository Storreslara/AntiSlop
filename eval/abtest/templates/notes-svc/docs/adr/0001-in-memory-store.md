# 1. In-memory note store

Status: accepted

The service keeps notes in a `Map` inside the process. There is no database and no file persistence; a restart empties the store. This keeps the service dependency-free and the tests fast. A durable store would be a new decision.
