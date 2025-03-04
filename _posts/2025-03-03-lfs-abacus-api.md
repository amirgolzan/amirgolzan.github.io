---
title: Abacus API
subtitle: "Search & Data Access"
author: "Mathew Vis-Dunbar & Nick Rochlin"
date: "2025-02-14 09:00:00 -0800"
categories: [R, API]
tags: [R, rstudio] # tags always lowercase
always_allow_html: yes
output: 
  html_document:
    keep_md: TRUE
---



## Definitions

**API**

An application programming interface (API) is a formalized way of interacting with another piece of hardware or software without needing to know how that hardware or software actually works. As such, it is a convenient method of making requests to get, update, or push information between your system and the remote system. As a loose analogy, you can think of this as a menu in a resuraunt; you don't need to know how the kitchen makes your food, but you need to know what you can ask for from your server. When you want scrambled eggs, you don't need to go into the kitchen and make these from scratch, you simply put in a request based on the options on the menu.

**JSON**

JavaScript Object Notation (JSON) is a method for storing and transmitting data primarily using key value pairs. It is compact, flexible, human readable, and works well in a Web based environment. It is generally the default format in which data is transmitted from an API.

## Set up

The Abacus API is accessible through http, which means we can access the API using any http compliant tool, including a web browser.

By default, the API returns data in JSON notation. One of the issues we have when working in `R` is that `R` excels with rectangular data, especially if working in the `Tidyverse`. So we need to wrangle the JSON formatted  data into a data structure more amenable to R. This begins by moving content into a list after which we can transition it to a dataframe, or tibble, as needed.

To do this all, we'll use the following four libraries, although, as we'll see later, we can get away with just the `httr2` package:


``` r
library(httr2) # http protocols
library(jsonlite) # json to r data structures
```

## Steps

In the proceding sections we'll cover the following steps:

1. Using the `search` API to look for relevant datasets.
2. Plugging a unique ID associated with the dataset(s) of interest into the `datasets` api to identify the files of interest. This involves first identifying a new unique ID for each dataset, only accessible through the `datasets` API, and the version of the dataset we're interested in (an Abacus record is version controlled).
3. We will then use the urls associated with the data files to download the relevant data.

We will be working with the Statistics Canada Labour Force Surveys for this exercise.

## Caveats

This is a simplified overview of API interactions. So, for example, we will not be doing any error handling, nor will we deal with using authentication tokens. But these are easily built in once the general approach is understood, and the `httr2` package has functions for handling these things.

## Building the Connection

Abacus is built on a Dataverse instance. You can [refer to the Dataverse API documentation](https://guides.dataverse.org/en/latest/api/index.html) for more information on interacting with the API.

Abacus has more than one API. This is common when interacting with APIs. Each API gives you access to certain functionalities and returns certain pieces of data. Here, we'll review the `search` and `datasets` APIs; the former to locate content, the latter to retrieve that content. We will ultimately use the `access` API with `download.file()` to acquire the data.

In either case, we start with the base url into the API, which we'll store in a variable.


``` r
base_url <- "https://abacus.library.ubc.ca/api/"
```

Next, we can add on the specific API we intend to search.


``` r
search_api <- "search?q="
```

The `search` API requires a `query` parameter, ie, something to search for. This is articulated as a string, following the `?q=`.

Note: When using the `httr2` package, if the query string is multi-word, spaces need to be filled with `%20`. For example, a search for `labour force` will fail, and need to be replaced with `labour%20force`.

## Search API

There are a variety of fields and file types that we can search through the search API, noting that, as a data repository, objects in Abacus are organized into dataverses, datasets, and files, where datasets reside in dataverses, and files within datasets. Datasets provide a high level overview of the data they hold, including descriptions, number of files, who produced the files, when they were uploaded, etc.

We've already built our `base_url` and added on the requisite text to access the `search` API, `search_api`. We'll now build our query, specifying the query and the file type of interest, ie, do we want to search for a dataverse, dataset, or file.


``` r
search_query <- "title:labour" # retrieve everything with the word labour in the title
search_type <- "&type=dataset" # limit to datasets
```

We can then paste these together to construct a full query.


``` r
(search_api_call <- paste0(base_url, search_api, search_query, search_type))
```

```
## [1] "https://abacus.library.ubc.ca/api/search?q=title:labour&type=dataset"
```

To get a sense of what this looks like, we can load this query in our browser.

## Implementing the Search in `R`

The `hhtr2` package will allow us to make http requests from within `R`. The steps involved including:

a) building a request; and then
b) performing that request, which results in some data being sent back to us.

These two steps are done, respectively, with the `request()` and `req_perform()` functions. We feed our `search_api_call` into the `request()` and then feed the result into the `req_preform`.


``` r
search_resp <- search_api_call |>
  httr2::request() |>
  httr2::req_perform()
```

What we get back is the same as what we saw in our browser, formatted as a list.


``` r
str(search_resp)
```

```
## List of 7
##  $ method     : chr "GET"
##  $ url        : chr "https://abacus.library.ubc.ca/api/search?q=title:labour&type=dataset"
##  $ status_code: int 200
##  $ headers    :List of 8
##   ..$ Date                        : chr "Tue, 04 Mar 2025 04:59:15 GMT"
##   ..$ Server                      : chr "Apache/2.4.37 (Red Hat Enterprise Linux) OpenSSL/1.1.1k mod_R/1.2.9 R/3.5.0 mod_apreq2-20101207/2.8.1"
##   ..$ X-Frame-Options             : chr "SAMEORIGIN"
##   ..$ Access-Control-Allow-Origin : chr "*"
##   ..$ Access-Control-Allow-Methods: chr "PUT, GET, POST, DELETE, OPTIONS"
##   ..$ Access-Control-Allow-Headers: chr "Accept, Content-Type, X-Dataverse-Key"
##   ..$ Content-Type                : chr "application/json;charset=UTF-8"
##   ..$ Transfer-Encoding           : chr "chunked"
##   ..- attr(*, "class")= chr "httr2_headers"
##  $ body       : raw [1:24871] 7b 22 73 74 ...
##  $ request    :List of 7
##   ..$ url     : chr "https://abacus.library.ubc.ca/api/search?q=title:labour&type=dataset"
##   ..$ method  : NULL
##   ..$ headers : list()
##   ..$ body    : NULL
##   ..$ fields  : list()
##   ..$ options : list()
##   ..$ policies: list()
##   ..- attr(*, "class")= chr "httr2_request"
##  $ cache      :<environment: 0x11485b238> 
##  - attr(*, "class")= chr "httr2_response"
```

What we're most interested in here is the `body`. However, the `body` is sent to us structured as json and in raw bytes. This is generally the case with an API response. `httr2` has a built in function for converting the body from raw to something `R` can work with -- `resp_body_json()` -- and we'll use this later, but we'll start with the `jsonlite` package to explore this process step by step.


``` r
summary(search_resp$body)
```

```
## Length  Class   Mode 
##  24871    raw    raw
```

Since we only want the `body` going forward, we'll isolate this.


``` r
search_body <- search_resp$body
```

## Data Wrangling

Our first task is to convert this raw data to character data. We can do this with `rawToChar`.


``` r
search_body_char <- rawToChar(search_body)
```

We're presented with a vector of length one, which if we print out the first bit of, does not look very friendly.


``` r
summary(search_body_char)
```

```
##    Length     Class      Mode 
##         1 character character
```

``` r
str(search_body_char)
```

```
##  chr "{\"status\":\"OK\",\"data\":{\"q\":\"title:labour\",\"total_count\":110,\"start\":0,\"spelling_alternatives\":{"| __truncated__
```

This looks a little friendlier with `cat()`


``` r
# not executed
cat(search_body_char)
```

Our next task then, is to convert this JSON notation to a suitable `R` data structure, in this case, a list. We'll do this with the `jsonlite` package.


``` r
search_body_list <- jsonlite::fromJSON(search_body_char)
```

If we look at how this has been converted, we can see it's a list of two.


``` r
summary(search_body_list)
```

```
##        Length Class  Mode     
## status 1      -none- character
## data   6      -none- list
```

The `data` list is what we want. We'll pull that out and then explore that list.


``` r
search_data <- search_body_list$data
summary(search_data)
```

<table class="table table-striped" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;">   </th>
   <th style="text-align:left;"> Length </th>
   <th style="text-align:left;"> Class </th>
   <th style="text-align:left;"> Mode </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> q </td>
   <td style="text-align:left;"> 1 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
  <tr>
   <td style="text-align:left;"> total_count </td>
   <td style="text-align:left;"> 1 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> numeric </td>
  </tr>
  <tr>
   <td style="text-align:left;"> start </td>
   <td style="text-align:left;"> 1 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> numeric </td>
  </tr>
  <tr>
   <td style="text-align:left;"> spelling_alternatives </td>
   <td style="text-align:left;"> 0 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> list </td>
  </tr>
  <tr>
   <td style="text-align:left;"> items </td>
   <td style="text-align:left;"> 27 </td>
   <td style="text-align:left;"> data.frame </td>
   <td style="text-align:left;"> list </td>
  </tr>
  <tr>
   <td style="text-align:left;"> count_in_response </td>
   <td style="text-align:left;"> 1 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> numeric </td>
  </tr>
</tbody>
</table>

We're slowly whittling this down. This now looks almost identical to what we pulled up in our browser earlier. The actual relevant content is in the `items` list. But we'll also need the `total_count` for when we need to request all the data from the server in a loop. For now, let's look at the 26 items in there.


``` r
names(search_data$items)
```

```
##  [1] "name"                    "type"                   
##  [3] "url"                     "global_id"              
##  [5] "description"             "published_at"           
##  [7] "publisher"               "citationHtml"           
##  [9] "identifier_of_dataverse" "name_of_dataverse"      
## [11] "citation"                "storageIdentifier"      
## [13] "keywords"                "subjects"               
## [15] "fileCount"               "versionId"              
## [17] "versionState"            "majorVersion"           
## [19] "minorVersion"            "createdAt"              
## [21] "updatedAt"               "contacts"               
## [23] "producers"               "relatedMaterial"        
## [25] "geographicCoverage"      "authors"                
## [27] "publications"
```

We don't need all this data. We should be able to do some evaluation with the `name`, `description`, `fileCount`, `producers`, `published_at`, `url`, and, for later retrieval, `global_id`. Let's look at these quickly, noting importantly, that `producers` is another list, that we'll need to wrangle some how.


``` r
vars_of_interest <- c("name", "description", "fileCount", "producers", "published_at", "url", "global_id")
lapply(search_data$items[vars_of_interest], class) # show the class of each list item
```

```
## $name
## [1] "character"
## 
## $description
## [1] "character"
## 
## $fileCount
## [1] "integer"
## 
## $producers
## [1] "list"
## 
## $published_at
## [1] "character"
## 
## $url
## [1] "character"
## 
## $global_id
## [1] "character"
```

## Getting All the Data

At this stage, we have what we need to pull search results from Abacus. You'll note that the search returned a result set of 109, but only 10 items:


``` r
(search_body_list$data$total_count)
```

```
## [1] 110
```

``` r
(nrow(search_body_list$data$items))
```

```
## [1] 10
```

Going forward, we need to paginate through the result set to retrieve all the items.

A few things to note:

* By default, the `search` API returns 10 results per request. It allows for a maximum of 1000 per request. This is handled in the `per_page` parameter.
* There is a start parameter that we can feed into the request; this indicates which record to start retrieving data from. This number will need to be updated as we iterate over our requests, for example, if in the first call we pull records 1:1000, in the second call, we need to start at 1001. This is handled in the `start` parameter.
* `R` starts counting at 1, other languages start at 0, so the first record returned by the API is indexed at 0 on the server, not 1.
* APIs will have a limit on the number of requests you can make in any given time span. We'll build in a simple delay using `Sys.Sleep()`, but `httr2` has a built in function for handling this as well.

Below is a function with the above steps built into it. It takes two arguments, a search string and the number of results to retrieve per request. It also prints some progress information to the console.


``` r
search_datasets <- function(query, per_page) {
  # Build the query
  url <- paste0("https://abacus.library.ubc.ca/api/search?q=", query, "&type=dataset")
  
  # Initial call to figure out total records
  resp <- url |>
    httr2::request() |>
    httr2::req_perform()
  resp_body <- jsonlite::fromJSON(rawToChar(resp$body))
  total_count <- resp_body$data$total_count
  
  # Give some feedback
  cat(paste0("There are ", total_count, " records to be fetched.\n", "Fetching ", per_page, " records per call.\nThis will require ", ceiling(total_count/per_page), " calls.\n\n"))
  
  # build place holders for loop
  name <- vector()
  description <- vector()
  file_count <- vector()
  producers <- list()
  pub_date <- vector()
  global_id <- vector()
  handle <- vector()
  
  # establish the starting point
  start_point <- 0
  
  # create a counter for tracking calls
  call_counter <- 1
  
  # run the loop
  while(length(handle) < total_count) { # while the number of retrieved records is < the total count
    cat(paste0("Call ", call_counter, "\n")) # Indicate what call we're on to the API
    req <- httr2::request(paste0(url, "&start=", start_point, "&per_page=", per_page)) # create the request
    resp <- httr2::req_perform(req) # perform the request
    resp_body <- jsonlite::fromJSON(rawToChar(resp$body)) # convert the body from raw JSON to a list
    resp_body_name <- resp_body$data$items$name # get the name
    resp_body_desc <- resp_body$data$items$description # get the description
    resp_body_file_count <- resp_body$data$items$fileCount # get the file count
    resp_body_producers <- resp_body$data$items$producers # get the producers
    resp_body_handle <- resp_body$data$items$url #get the url
    resp_body_global_id <- resp_body$data$items$global_id # get id
    resp_body_pubdate <- resp_body$data$items$published_at # get update date
    # update the place holders:
    name <- c(name, resp_body_name)
    description <- c(description, resp_body_desc)
    file_count <- c(file_count, resp_body_file_count)
    producers <- c(producers, resp_body_producers)
    pub_date <- c(pub_date, resp_body_pubdate)
    handle <- c(handle, resp_body_handle)
    global_id <- c(global_id, resp_body_global_id)
    # update counters
    start_point <- start_point + per_page # increment the start_point
    call_counter <- call_counter + 1 # increment the counter
    Sys.sleep(.1) # pause before making a new call
  }
  # When all is said and done, compile the place holders into a list and return this object
    return(list("name" = name,
                "description" = description,
                "file_count" = file_count,
                "producers" = producers,
                "pub_date" = pub_date,
                "handle" = handle,
                "global_id" = global_id))
}
```

We can then call that function, here adding an additional parameter indicating that we only want to search the title and that we want 50 results per query. We're being specifically broad with our search.


``` r
labour <- search_datasets("title:labour", 50)
```

```
## There are 110 records to be fetched.
## Fetching 50 records per call.
## This will require 3 calls.
## 
## Call 1
## Call 2
## Call 3
```

We now have record data that we can explore.


``` r
summary(labour)
```

<table class="table table-striped" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;">   </th>
   <th style="text-align:left;"> Length </th>
   <th style="text-align:left;"> Class </th>
   <th style="text-align:left;"> Mode </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> name </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
  <tr>
   <td style="text-align:left;"> description </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
  <tr>
   <td style="text-align:left;"> file_count </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> numeric </td>
  </tr>
  <tr>
   <td style="text-align:left;"> producers </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> list </td>
  </tr>
  <tr>
   <td style="text-align:left;"> pub_date </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
  <tr>
   <td style="text-align:left;"> handle </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
  <tr>
   <td style="text-align:left;"> global_id </td>
   <td style="text-align:left;"> 110 </td>
   <td style="text-align:left;"> -none- </td>
   <td style="text-align:left;"> character </td>
  </tr>
</tbody>
</table>

We can make this a bit easier for ourselves by converting this into a dataframe or tibble. There are several ways to approach this, considering that `producers` is a list -- it is a list as some records have more than one producer associated them. Here, I'll treat datasets with multiple producers as a different record authority than if one of these co-producers produced a standalone dataset. To do this, we'll first collapse the `producers` nested lists, and then flatten the result into a single list.


``` r
labour$producers <- labour$producers |>
  lapply(function(x) paste(x, collapse = ", ")) |>
  unlist()

head(labour$producers, n = 20)
```

```
##  [1] "Statistics Canada. Labour Force Survey Division"
##  [2] "Statistics Canada. Labour Force Survey Division"
##  [3] "Statistics Canada"                              
##  [4] "Statistics Canada"                              
##  [5] "Statistics Canada"                              
##  [6] "Statistics Canada"                              
##  [7] "Statistics Canada"                              
##  [8] "Statistics Canada"                              
##  [9] "Statistics Canada"                              
## [10] "Statistics Canada"                              
## [11] "Statistics Canada"                              
## [12] "Statistics Canada"                              
## [13] "Statistics Canada"                              
## [14] "Statistics Canada"                              
## [15] "Statistics Canada"                              
## [16] "Statistics Canada"                              
## [17] "Statistics Canada"                              
## [18] "Statistics Canada"                              
## [19] "Statistics Canada"                              
## [20] "Statistics Canada"
```

We can easily convert this to a dataframe now.


``` r
labour <- as.data.frame(labour)
head(labour)
```

<table class="table table-striped" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;"> name </th>
   <th style="text-align:left;"> description </th>
   <th style="text-align:right;"> file_count </th>
   <th style="text-align:left;"> producers </th>
   <th style="text-align:left;"> pub_date </th>
   <th style="text-align:left;"> handle </th>
   <th style="text-align:left;"> global_id </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2013 </td>
   <td style="text-align:left;"> The Labour Force Survey (LFS) is a household... </td>
   <td style="text-align:right;"> 14 </td>
   <td style="text-align:left;"> Statistics Canada. Labour Force Survey Division </td>
   <td style="text-align:left;"> 2013-09-10T07:00:00Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/HTSWUF </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/HTSWUF </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2014 </td>
   <td style="text-align:left;"> The Labour Force Survey (LFS) is a household... </td>
   <td style="text-align:right;"> 29 </td>
   <td style="text-align:left;"> Statistics Canada. Labour Force Survey Division </td>
   <td style="text-align:left;"> 2014-01-01T08:00:00Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/SDAVTH </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/SDAVTH </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2023 </td>
   <td style="text-align:left;"> LFS data are used to produce the well-known ... </td>
   <td style="text-align:right;"> 31 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2024-01-05T17:38:25Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/IJU1QK </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/IJU1QK </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2006 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:47:04Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/0B5LPL </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/0B5LPL </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2008 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:47:20Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/LA3WXI </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/LA3WXI </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2007 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:29:41Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/NANO81 </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/NANO81 </td>
  </tr>
</tbody>
</table>

## Explore

We have several datasets with labour in the title. One way of handling exploring this is to strip the dates so that we can look for unique values. First we extract the date:


``` r
labour$year <- gsub(".*?([0-9]+).*$", "\\1", labour$name) # regex to find ending numbers and storing in a new var
head(labour$year)
```

```
## [1] "2013" "2014" "2023" "2006" "2008" "2007"
```

Then we strip the name:


``` r
labour$name_no_year <- trimws(gsub("[[:punct:]]|[[:digit:]]", "", labour$name)) # regex to remove punctuation and remaing numbers
head(labour$name_no_year)
```

```
## [1] "Labour Force Survey" "Labour Force Survey" "Labour Force Survey"
## [4] "Labour Force Survey" "Labour Force Survey" "Labour Force Survey"
```

And then look at the unique values:


``` r
(unique(labour$name_no_year))
```

```
##  [1] "Labour Force Survey"                                                             
##  [2] "Survey of Labour and Income Dynamics"                                            
##  [3] "Cultural Labour Force Survey"                                                    
##  [4] "Survey of Persons Not in the Labour Force"                                       
##  [5] "Labour Force Income Profiles"                                                    
##  [6] "Labour Force Survey Rebased Revised"                                             
##  [7] "Survey of Labour and Income Dynamics Reweighted"                                 
##  [8] "Labour Force Survey  revision"                                                   
##  [9] "Labour Income Profile for selected BC communities"                               
## [10] "Labour Market Activity Survey"                                                   
## [11] "Labour force historical review"                                                  
## [12] "Small Area Business and Labour Database"                                         
## [13] "Labour Force Historical Review"                                                  
## [14] "Interwar Labour Database"                                                        
## [15] "Experienced Labour Force Population by Occupation custom tabulation"             
## [16] "Labour Market Activity Survey Crosssectional Files"                              
## [17] "Experienced Labour Force Population by Industry and Occupation custom tabulation"
## [18] "Labour Market Activity Survey Longitudinal Files"                                
## [19] "New Survey of London Life and Labour"
```

We only need the Labour Force Surveys themselves. These are occasionally revised, [documentation on these revisions here](https://www150.statcan.gc.ca/n1/pub/71f0031x/71f0031x2023001-eng.htm), hence multiple records with slightly modified names (Labour Force Survey, Labour Force Survey (Rebased, Revised), etc)


``` r
lfs <- labour[grepl("^Labour Force Survey", labour$name_no_year),] # regex to find names starting with LFS
head(lfs)
```

<table class="table table-striped" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;"> name </th>
   <th style="text-align:left;"> description </th>
   <th style="text-align:right;"> file_count </th>
   <th style="text-align:left;"> producers </th>
   <th style="text-align:left;"> pub_date </th>
   <th style="text-align:left;"> handle </th>
   <th style="text-align:left;"> global_id </th>
   <th style="text-align:left;"> year </th>
   <th style="text-align:left;"> name_no_year </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2013 </td>
   <td style="text-align:left;"> The Labour Force Survey (LFS) is a household... </td>
   <td style="text-align:right;"> 14 </td>
   <td style="text-align:left;"> Statistics Canada. Labour Force Survey Division </td>
   <td style="text-align:left;"> 2013-09-10T07:00:00Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/HTSWUF </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/HTSWUF </td>
   <td style="text-align:left;"> 2013 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2014 </td>
   <td style="text-align:left;"> The Labour Force Survey (LFS) is a household... </td>
   <td style="text-align:right;"> 29 </td>
   <td style="text-align:left;"> Statistics Canada. Labour Force Survey Division </td>
   <td style="text-align:left;"> 2014-01-01T08:00:00Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/SDAVTH </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/SDAVTH </td>
   <td style="text-align:left;"> 2014 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2023 </td>
   <td style="text-align:left;"> LFS data are used to produce the well-known ... </td>
   <td style="text-align:right;"> 31 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2024-01-05T17:38:25Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/IJU1QK </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/IJU1QK </td>
   <td style="text-align:left;"> 2023 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2006 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:47:04Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/0B5LPL </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/0B5LPL </td>
   <td style="text-align:left;"> 2006 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2008 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:47:20Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/LA3WXI </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/LA3WXI </td>
   <td style="text-align:left;"> 2008 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Labour Force Survey, 2007 </td>
   <td style="text-align:left;"> The Labour Force Survey provides estimates o... </td>
   <td style="text-align:right;"> 26 </td>
   <td style="text-align:left;"> Statistics Canada </td>
   <td style="text-align:left;"> 2023-03-16T21:29:41Z </td>
   <td style="text-align:left;"> https://hdl.handle.net/11272.1/AB2/NANO81 </td>
   <td style="text-align:left;"> hdl:11272.1/AB2/NANO81 </td>
   <td style="text-align:left;"> 2007 </td>
   <td style="text-align:left;"> Labour Force Survey </td>
  </tr>
</tbody>
</table>

## Looking at Files

We now know the data sets we're interested in. A dataset is made up of multiple files, however, and we likely don't want all the files for every dataset. We'll start by getting the file list for one of our datasets. Once we can do this for one dataset, we can iterate over all the datasets, although we won't implement that in this workshop.

Up until now, we've been using the `search` api. We'll now use the `datasets` api.


``` r
datasets_api <- "datasets/"
```

Like before, we'll build our query. We'll start with the 2011 LFS dataset. This is a multi-step process, as the first thing we need to do is get the `id` for the dataset, which is different from the `global_id` we retrieved from the `search` api, but we need the `global_id`, piped into the `datasets` api, to get the `id`.


``` r
id <- lfs[lfs$name == "Labour Force Survey, 2011", "global_id", drop = TRUE] # we want a simple vector returned
query <- paste0(":persistentId/?persistentId=", id) # limit to the id of interest, see dataverse API documentation
(dataset_api_call <- paste0(base_url, datasets_api, query)) # build the call
```

```
## [1] "https://abacus.library.ubc.ca/api/datasets/:persistentId/?persistentId=hdl:11272.1/AB2/GK3SFF"
```

Now we make the call and process the `body`.


``` r
dataset_id_resp <- dataset_api_call |>
  httr2::request() |>
  httr2::req_perform()
dataset_id_body <- jsonlite::fromJSON(rawToChar(dataset_id_resp$body))
```

We need the `id` and the `versionNumber` to access a file list.

Building the call:


``` r
dataset_id <- dataset_id_body$data$id
dataset_ver <- dataset_id_body$data$latestVersion$versionNumber
(file_list_query <- paste0(base_url, datasets_api, dataset_id, "/versions/", dataset_ver, "/files/"))
```

```
## [1] "https://abacus.library.ubc.ca/api/datasets/45508/versions/2/files/"
```

Then execute, this time using the `httr2` option, `resp_body_json()` to convert the body to an `R` object, as it's a bit more streamlined.


``` r
dataset_file_resp <- file_list_query |>
  httr2::request() |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

Files are generally indicated as being either data, documentation, or command files. We'll isolate just the data files in the list. All relevant data files have a `directoryLabel` equal to `Data`. We can use this to access only the data files.


``` r
data_files <- Filter(function(x) x$directoryLabel == "Data", dataset_file_resp$data) # filter by directoryLabel
```

We'll list out the files


``` r
for(i in 1:length(data_files)){
  print(data_files[[i]]$label)
}
```

```
## [1] "LFS_April_2011.tab"
## [1] "LFS_August_2011.tab"
## [1] "LFS_December_2011.tab"
## [1] "LFS_February_2011.tab"
## [1] "LFS_January_2011.tab"
## [1] "LFS_July_2011.tab"
## [1] "LFS_June_2011.tab"
## [1] "LFS_March_2011.tab"
## [1] "LFS_May_2011.tab"
## [1] "LFS_November_2011.tab"
## [1] "LFS_October_2011.tab"
## [1] "LFS_September_2011.tab"
## [1] "pub0111.prn"
## [1] "pub0211.prn"
## [1] "pub0311.prn"
## [1] "pub0411.prn"
## [1] "pub0511.prn"
## [1] "pub0611.prn"
## [1] "pub0711.prn"
## [1] "pub0811.prn"
## [1] "pub0911.prn"
## [1] "pub1011.prn"
## [1] "pub1111.prn"
## [1] "pub1211.prn"
```

From which we'll see that there are two different formats available to us. Let's grab just the `.tab` files.


``` r
relevant_data_files <- Filter(function(x) grepl("tab$", x$label), data_files) # filter to files ending in tab
```

And then download them.


``` r
dir.create("LFS_2011") # create a directory
```

```
## Warning in dir.create("LFS_2011"): 'LFS_2011' already exists
```

``` r
dest_dir <- "LFS_2011/" # store it in a variable

# loop through the files and download them
for(i in 1:length(relevant_data_files)){
  file_name <- relevant_data_files[[i]]$label
  file_id <- relevant_data_files[[i]]$dataFile$id
  url_root <- "https://abacus.library.ubc.ca/api/access/datafile/"
  download.file(url = paste0(url_root, file_id), destfile = paste0(dest_dir, file_name))
}
```



And build an annual set


``` r
lfs_2011_list <- lapply(list.files(dest_dir), function(x) read.delim(file = paste0(dest_dir, x))) # read in each tab file into a list
lfs_2011_df <- do.call(rbind, lfs_2011_list) # bind the list items into a df
summary(lfs_2011_df[, c(1:11)]) |>
  kbl() |>
  kable_styling(bootstrap_options = "striped")
```

<table class="table table-striped" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;">   </th>
   <th style="text-align:left;">    REC_NUM </th>
   <th style="text-align:left;">    SURVYEAR </th>
   <th style="text-align:left;">    SURVMNTH </th>
   <th style="text-align:left;">    LFSSTAT </th>
   <th style="text-align:left;">      PROV </th>
   <th style="text-align:left;">      CMA </th>
   <th style="text-align:left;">     AGE_12 </th>
   <th style="text-align:left;">     AGE_6 </th>
   <th style="text-align:left;">      SEX </th>
   <th style="text-align:left;">    MARSTAT </th>
   <th style="text-align:left;">      EDUC </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Min.   :     1 </td>
   <td style="text-align:left;"> Min.   :2011 </td>
   <td style="text-align:left;"> Min.   : 1.000 </td>
   <td style="text-align:left;"> Min.   :1.00 </td>
   <td style="text-align:left;"> Min.   :10.0 </td>
   <td style="text-align:left;"> Min.   :0.000 </td>
   <td style="text-align:left;"> Min.   : 1.000 </td>
   <td style="text-align:left;"> Min.   :1.0 </td>
   <td style="text-align:left;"> Min.   :1.000 </td>
   <td style="text-align:left;"> Min.   :1.000 </td>
   <td style="text-align:left;"> Min.   :0.000 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> 1st Qu.: 26294 </td>
   <td style="text-align:left;"> 1st Qu.:2011 </td>
   <td style="text-align:left;"> 1st Qu.: 4.000 </td>
   <td style="text-align:left;"> 1st Qu.:1.00 </td>
   <td style="text-align:left;"> 1st Qu.:24.0 </td>
   <td style="text-align:left;"> 1st Qu.:0.000 </td>
   <td style="text-align:left;"> 1st Qu.: 4.000 </td>
   <td style="text-align:left;"> 1st Qu.:2.0 </td>
   <td style="text-align:left;"> 1st Qu.:1.000 </td>
   <td style="text-align:left;"> 1st Qu.:1.000 </td>
   <td style="text-align:left;"> 1st Qu.:2.000 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Median : 52587 </td>
   <td style="text-align:left;"> Median :2011 </td>
   <td style="text-align:left;"> Median : 7.000 </td>
   <td style="text-align:left;"> Median :1.00 </td>
   <td style="text-align:left;"> Median :35.0 </td>
   <td style="text-align:left;"> Median :0.000 </td>
   <td style="text-align:left;"> Median : 7.000 </td>
   <td style="text-align:left;"> Median :4.0 </td>
   <td style="text-align:left;"> Median :2.000 </td>
   <td style="text-align:left;"> Median :2.000 </td>
   <td style="text-align:left;"> Median :3.000 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Mean   : 52589 </td>
   <td style="text-align:left;"> Mean   :2011 </td>
   <td style="text-align:left;"> Mean   : 6.509 </td>
   <td style="text-align:left;"> Mean   :2.19 </td>
   <td style="text-align:left;"> Mean   :35.1 </td>
   <td style="text-align:left;"> Mean   :1.473 </td>
   <td style="text-align:left;"> Mean   : 6.765 </td>
   <td style="text-align:left;"> Mean   :3.5 </td>
   <td style="text-align:left;"> Mean   :1.516 </td>
   <td style="text-align:left;"> Mean   :2.834 </td>
   <td style="text-align:left;"> Mean   :3.008 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> 3rd Qu.: 78880 </td>
   <td style="text-align:left;"> 3rd Qu.:2011 </td>
   <td style="text-align:left;"> 3rd Qu.: 9.000 </td>
   <td style="text-align:left;"> 3rd Qu.:4.00 </td>
   <td style="text-align:left;"> 3rd Qu.:47.0 </td>
   <td style="text-align:left;"> 3rd Qu.:2.000 </td>
   <td style="text-align:left;"> 3rd Qu.:10.000 </td>
   <td style="text-align:left;"> 3rd Qu.:5.0 </td>
   <td style="text-align:left;"> 3rd Qu.:2.000 </td>
   <td style="text-align:left;"> 3rd Qu.:6.000 </td>
   <td style="text-align:left;"> 3rd Qu.:4.000 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> Max.   :106352 </td>
   <td style="text-align:left;"> Max.   :2011 </td>
   <td style="text-align:left;"> Max.   :12.000 </td>
   <td style="text-align:left;"> Max.   :4.00 </td>
   <td style="text-align:left;"> Max.   :59.0 </td>
   <td style="text-align:left;"> Max.   :9.000 </td>
   <td style="text-align:left;"> Max.   :12.000 </td>
   <td style="text-align:left;"> Max.   :6.0 </td>
   <td style="text-align:left;"> Max.   :2.000 </td>
   <td style="text-align:left;"> Max.   :6.000 </td>
   <td style="text-align:left;"> Max.   :6.000 </td>
  </tr>
  <tr>
   <td style="text-align:left;">  </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA's   :975211 </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
   <td style="text-align:left;"> NA </td>
  </tr>
</tbody>
</table>
