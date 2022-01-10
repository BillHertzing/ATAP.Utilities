#Images Still and Moving

ToDo  Move into a Features subdirectory of SolutionDocumentatation

## Operations on an image file

  To prepare it for further development work
      copy the original into a workspace
      archive the original (optional)
  To prepare it for publishing publicly
    Strip out PII from persistence (file or db records) Metadata.
    Select other Metadata to keep
    Add descriptive text and title
    Create multiple smaller files shrunken to specific sizes
    test (ToDo: Link to Document on how to test image features)
    authorize (ToDo: Link to Document on how to authorize the release of a new / modified content to production deployment headwaters)
    copy final ReleaseToProduction version of file or db to production deployment pipeline source persistence location


## To use a image features outputs

### In a blog post

Use a realtive link in the current theme to the agreed upon relative source location (./images or ./resources/images) of the filename or db records keys. Whater rendering tool (editor, usually) is used, it should be showing the image. For moving images, the rendering may, or may not, include the image in motion. During document editing, it may be faster if only a placeholder is shown. The placeholder if used, should appear in the very same location as the production rendering. The feature should be as WYS in development is as close as possible to WYG in production.

The blog post includes the metadata (media calls, etc) that tell the browser (client) that image links may exist in multiple sizes for some or all of the images referenced in the blog post.

### In online Documentation of a product or feature



# Adding the image features to a CI/CD pipeline

Tell the deployment pipeline the name of the blog
Copy the blog file or db to a workspace
Scan the blog for image filenames, title, or descriptivetext.
Create List of persistence image sources
Copy as many as possible of them to cloud location for image hosting service
Get authroizartion links that allow internet users to view
Update the blog information with the new links to the cloud sources
Alert and log on any blog links that did
not have matching images. also any images found in the source location that did not have matching links in the blog.

