open Lwt.Infix
open Models

let timeline_handler _request =
  let photos = get_photos ~limit:10 () in
  let last_timestamp =
    match List.rev photos with
    | [] -> Unix.time ()
    | last_photo :: _ -> last_photo.timestamp
  in
  let context : Mustache.Json.t = `O [
    ("title", `String "Photo Timeline");
    ("photos", `A (List.map Templates.photo_to_json photos));
    ("last_timestamp", `Float last_timestamp);
  ] in
  Templates.render_template "timeline.html" context >>= Dream.html



  let load_more_handler request =
    let before =
      match Dream.query request "before" with
      | Some ts -> (
          try Some (float_of_string ts) with
          | Failure _ -> None
        )
      | None -> None
    in
    let photos =
      match before with
      | Some timestamp -> get_photos ~before:timestamp ~limit:10 ()
      | None -> get_photos ~limit:10 ()
    in
    let context = `O [
      ("photos", `A (List.map Templates.photo_to_json photos));
    ] in
    Templates.render_template "photos.html" context >>= Dream.html

let () = 
  Dream.run
  @@ Dream.logger
  @@ Dream.logger
  @@ Dream.memory_sessions
  @@ Dream.router [

    Dream.get "/" timeline_handler;
    Dream.get "/load-more" load_more_handler;
    Dream.get "/static/**" (Dream.static "./static");

  ]
