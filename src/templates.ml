open Base
open Lwt.Infix
open Stdio

  
module Sys = Stdlib.Sys
module Filename = Stdlib.Filename
module StringMap = Base.Map.M(Base.String)

let photo_to_json (photo : Models.photo) : Mustache.Json.value =
  let iso_timestamp =
    (* Convert timestamp to ISO 8601 format *)
    let open Unix in
    let tm = gmtime photo.timestamp in
    Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
      (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
      tm.tm_hour tm.tm_min tm.tm_sec
  in
  let formatted_date =
    (* Format date as desired *)
    let open Unix in
    let tm = localtime photo.timestamp in
    Printf.sprintf "%02d-%02d-%04d"
      tm.tm_mday (tm.tm_mon + 1) (tm.tm_year + 1900)
  in
  `O [
    ("url", `String photo.url);
    ("description", `String photo.description);
    ("iso_timestamp", `String iso_timestamp);
    ("formatted_date", `String formatted_date);
  ]

let read_template name =
  let dev_templates_dir = Filename.concat "src" "templates" in
  let dev_filename = Filename.concat dev_templates_dir name in
  printf "Looking for template in development directory: %s\n%!" dev_filename;
  Lwt_unix.file_exists dev_filename >>= function
  | true ->
      printf "Using template from development directory: %s\n%!" dev_filename;
      Lwt_io.with_file ~mode:Lwt_io.Input dev_filename Lwt_io.read
  | false ->
      (* Try to use installed templates *)
      let templates_dir =
        Sys.getenv_opt "SNAPCAMEL_TEMPLATES"
        |> Option.value ~default:(
            let exe_dir = Filename.dirname Sys.executable_name in
            let share_dir = Filename.concat exe_dir "../share" in
            let package_name = "snapcamel" in
            Filename.concat share_dir (Filename.concat package_name "templates")
          )
      in
      let filename = Filename.concat templates_dir name in
      printf "Looking for template in installed directory: %s\n%!" filename;
      Lwt_unix.file_exists filename >>= function
      | true ->
          printf "Using template from installed directory: %s\n%!" filename;
          Lwt_io.with_file ~mode:Lwt_io.Input filename Lwt_io.read
      | false ->
          let error_msg = Printf.sprintf "Template file not found: %s" filename in
          Lwt.fail_with error_msg


let render_template name context =
  (* Read the main template *)
  read_template name >>= fun template_str ->
  (* Read partials *)
  let partial_names = ["base.html"] in  (* List all partials used *)
  Lwt_list.map_p read_template partial_names >>= fun partial_contents ->
  let partials =
    List.map2_exn partial_names partial_contents ~f:(fun name content ->
        (Filename.basename name, Mustache.of_string content))
    |> Map.of_alist_exn (module String)
  in
  let template = Mustache.of_string template_str in
  (* Render the template with partials *)
  let partials_lookup name = Map.find partials name in
  Lwt.return (Mustache.render ~partials:partials_lookup template context)
            