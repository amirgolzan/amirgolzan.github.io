#!/usr/bin/env Rscript

# --- Libraries ---
library(rmarkdown)
library(fs)  # For file utilities

# --- Settings / Inputs ---

# Path to your .Rmd file
input_rmd <- "_src/2023-07-06-Visualizing-With-Altair-in-Python.Rmd"

# Today’s date (for post filename and figure folder)
today_str <- as.character(Sys.Date())  
# e.g. "2025-02-04"

# Get the base name without the extension
rmd_basename <- tools::file_path_sans_ext(basename(input_rmd))
# e.g. "2024-10-07-transforming-data"

# Create a slug by removing any leading date
slug <- sub("^\\d{4}-\\d{2}-\\d{2}-", "", rmd_basename)
# e.g. "transforming-data"

# Final .md filename: YYYY-MM-DD-slug.md
final_md_filename <- sprintf("%s-%s.md", today_str, slug)

# --- 1. Extract YAML from the .Rmd ---
extract_yaml <- function(file_path) {
  lines <- readLines(file_path)
  yaml_start <- which(lines == "---")[1]
  yaml_end <- which(lines == "---")[2]
  
  if (!is.na(yaml_start) && !is.na(yaml_end) && yaml_end > yaml_start) {
    return(lines[yaml_start:yaml_end])  # Extract YAML block
  }
  stop("No valid YAML front matter found in the .Rmd file.")
}

# --- 2. Render Rmd to Markdown ---
temp_output_dir <- tempdir()  # Render output to a temporary directory

render(
  input         = input_rmd,
  output_format = "md_document",
  output_file   = rmd_basename,  # e.g., "2024-10-07-transforming-data.md"
  output_dir    = temp_output_dir
)

# The rendered Markdown file
rendered_md <- file.path(temp_output_dir, paste0(rmd_basename, ".md"))

if (!file_exists(rendered_md)) {
  stop("Rendered Markdown file not found. Check rmarkdown output.")
}

# --- 3. Read and prepend YAML ---
md_lines <- readLines(rendered_md)
yaml_frontmatter <- extract_yaml(input_rmd)  # Get YAML from the original .Rmd
md_lines <- c(yaml_frontmatter, "", md_lines)  # Prepend YAML and add spacing

# --- 4. Move actual figure files and flatten the structure ---
fig_folder_old <- file.path(temp_output_dir, paste0(rmd_basename, "_files"))
fig_folder_new <- file.path("figures", paste0(today_str, "-", slug))

if (dir_exists(fig_folder_old)) {
  message("Moving actual figure files to 'figures'...")
  
  # Create the target folder if it doesn't exist
  dir_create(fig_folder_new)
  
  # Find all figure files in the nested structure
  figure_files <- dir_ls(fig_folder_old, recurse = TRUE, regexp = "\\.(png|jpeg|jpg|svg)$")
  
  # Move each figure directly to the new folder
  for (figure_file in figure_files) {
    file_copy(figure_file, fig_folder_new, overwrite = TRUE)
  }
  
  # --- Correct image paths in the Markdown file ---
  # Look for <img src="..."> and convert to Markdown syntax with flattened paths
  md_lines <- gsub(
    pattern = '<img src="[^"]*figure-markdown_strict/([^"]+)"[^>]*>',
    replacement = paste0('![](/figures/', today_str, '-', slug, '/\\1)'),
    x = md_lines
  )
}

# --- 5. Write the final .md post into _posts ---
dir_create("_posts")  # Ensure _posts exists
final_md_path <- file.path("_posts", final_md_filename)
writeLines(md_lines, final_md_path)

message("Post successfully created: ", final_md_path)
message("Figures moved to: ", fig_folder_new)
