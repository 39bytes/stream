import birl
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/result
import gleam/string

pub fn decoder(value: Dynamic) -> Result(birl.Time, List(dynamic.DecodeError)) {
  use str <- result.try(dynamic.string(value))
  birl.parse(str)
  |> result.map_error(fn(_) {
    [dynamic.DecodeError(expected: "date", found: str, path: [])]
  })
}

pub fn format_date(date: birl.Time) -> String {
  let day = birl.get_day(date)
  let time = birl.get_time_of_day(date)

  [
    birl.short_string_month(date),
    int.to_string(day.date) <> ",",
    int.to_string(day.year),
    birl.time_of_day_to_short_string(time),
  ]
  |> string.join(" ")
}
