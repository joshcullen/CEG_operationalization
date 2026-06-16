
### Script to delete processed CMEMS files directly from GH repo dir

library(httr)
library(jsonlite)
library(lubridate)
library(stringr)

# --- CONFIGURATION ---
OWNER <- "joshcullen"
REPO <- "CEG_operationalization"
BRANCH <- "main" 
DAYS_OLD <- 60
DRY_RUN <- FALSE 

GITHUB_TOKEN <- Sys.getenv("GITHUB_PAT")

if (is.null(GITHUB_TOKEN) || GITHUB_TOKEN == "") {
  stop("GITHUB_TOKEN environment variable not set. This is required.")
}

HEADERS <- c(
  Authorization = paste("token", GITHUB_TOKEN),
  Accept = "application/vnd.github.v3+json",
  `X-GitHub-Api-Version` = "2022-11-28"
)

CUTOFF_DATE <- today() - days(DAYS_OLD)
print(paste("Cutoff Date (files older than this will be deleted):", CUTOFF_DATE))

DATE_PATTERN <- "(\\d{4}-\\d{2}-\\d{2})" 
DATE_FORMAT <- "%Y-%m-%d"

DIRECTORIES_TO_CLEAN <- c(
  "data_acquisition/netcdfs/cmems_ncdfs",
  "data_processing/TopPredatorWatch/rasters"
)

# ----------------------------------------------------

print("--- Fetching current branch reference ---")
ref_url <- paste0("https://api.github.com/repos/", OWNER, "/", REPO, "/git/refs/heads/", BRANCH)
ref_res <- GET(ref_url, add_headers(.headers = HEADERS))
stop_for_status(ref_res, task = "fetch branch reference")

ref_text <- content(ref_res, "text", encoding = "UTF-8")
commit_sha <- fromJSON(ref_text)$object$sha

print("--- Fetching entire repository tree (bypassing 1,000 file limits) ---")
# recursive=1 grabs everything in the repo, allowing us to see all files
tree_url <- paste0("https://api.github.com/repos/", OWNER, "/", REPO, "/git/trees/", commit_sha, "?recursive=1")
tree_res <- GET(tree_url, add_headers(.headers = HEADERS))
stop_for_status(tree_res, task = "fetch repository tree")

tree_data <- fromJSON(content(tree_res, "text", encoding = "UTF-8"))$tree

if (is.null(tree_data) || nrow(tree_data) == 0) {
  stop("Repository tree is empty or could not be parsed.")
}

# Filter for blob (files) that live inside our target directories
dir_pattern <- paste0("^(", paste(DIRECTORIES_TO_CLEAN, collapse="|"), ")")
files_to_check <- tree_data[tree_data$type == "blob" & grepl(dir_pattern, tree_data$path), ]

print(paste("Found", nrow(files_to_check), "files in target directories. Checking dates..."))

paths_to_delete <- c()

# Iterate through filtered files to find the old ones
for (i in seq_len(nrow(files_to_check))) {
  file_path <- files_to_check$path[i]
  file_name <- basename(file_path)
  
  date_match <- str_extract(file_name, DATE_PATTERN)
  
  if (!is.na(date_match)) {
    tryCatch({
      file_date <- as.Date(date_match, format = DATE_FORMAT)
      
      if (!is.na(file_date) && file_date < CUTOFF_DATE) {
        paths_to_delete <- c(paths_to_delete, file_path)
      }
    }, error = function(e) {
      # Silently skip files with malformed dates
    })
  }
}

print("=====================================================================")
print(paste("GLOBAL CLEANUP COMPLETE. TOTAL FILES MARKED FOR DELETION:", length(paths_to_delete)))

if (length(paths_to_delete) == 0) {
  print("No old files found to delete. Exiting successfully.")
  quit(save = "no")
}

# ----------------------------------------------------
# --- BATCH COMMIT PROCESS ---

if (DRY_RUN) {
  print("👀 DRY RUN (Would Delete in a Single Commit):")
  print(paths_to_delete)
} else {
  print("--- Building new Git tree for batch deletion ---")
  
  # By assigning sha = NULL to an existing file path, GitHub knows to delete it
  tree_items <- lapply(paths_to_delete, function(p) {
    list(
      path = p,
      mode = "100644",
      type = "blob",
      sha = NULL 
    )
  })
  
  new_tree_payload <- list(
    base_tree = commit_sha,
    tree = tree_items
  )
  
  new_tree_url <- paste0("https://api.github.com/repos/", OWNER, "/", REPO, "/git/trees")
  new_tree_res <- POST(new_tree_url, 
                       add_headers(.headers = HEADERS),
                       # Using auto_unbox and null="null" strictly structures the JSON for GitHub
                       body = toJSON(new_tree_payload, auto_unbox = TRUE, null = "null"), 
                       encode = "raw")
  stop_for_status(new_tree_res, task = "create new tree")
  
  new_tree_sha <- fromJSON(content(new_tree_res, "text", encoding = "UTF-8"))$sha
  
  print("--- Committing the new tree ---")
  commit_payload <- list(
    message = paste("Automated cleanup: Batch deleted", length(paths_to_delete), "old CMEMS/TopPred files"),
    tree = new_tree_sha,
    parents = list(commit_sha)
  )
  
  commit_url <- paste0("https://api.github.com/repos/", OWNER, "/", REPO, "/git/commits")
  commit_res <- POST(commit_url, 
                     add_headers(.headers = HEADERS),
                     body = toJSON(commit_payload, auto_unbox = TRUE), 
                     encode = "raw")
  stop_for_status(commit_res, task = "create commit")
  
  new_commit_sha <- fromJSON(content(commit_res, "text", encoding = "UTF-8"))$sha
  
  print("--- Updating branch reference ---")
  ref_update_payload <- list(
    sha = new_commit_sha,
    force = FALSE
  )
  
  ref_update_res <- PATCH(ref_url, 
                          add_headers(.headers = HEADERS),
                          body = toJSON(ref_update_payload, auto_unbox = TRUE), 
                          encode = "raw")
  stop_for_status(ref_update_res, task = "update branch reference")
  
  print("✅ SUCCESS: All files removed in a single, clean commit.")
}
