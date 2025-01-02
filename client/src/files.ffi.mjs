import { Ok, Error } from "./gleam.mjs";

export function on_paste(e) {
  const files = e.clipboardData.files;
  if (files.length === 0) {
    return null;
  }

  const file = files[0];
  if (!file.type.startsWith("image/")) return null;
  console.log(file);

  const formData = new FormData();
  formData.append("attachment", files[0]);
  console.log(formData);
  return formData;
}

export async function send_with_form_data(url, formData) {
  console.log(formData);
  try {
    return new Ok(await fetch(url, { method: "POST", body: formData }));
  } catch (error) {
    return new Error(new NetworkError(error.toString()));
  }
}
