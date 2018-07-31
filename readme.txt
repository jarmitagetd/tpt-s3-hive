/*------------------------------------------------------------------------*/
/* README:    TPT export to S3 and automated Hive table build for s3      */
/* AUTHOR:    James Armitage, Teradata                                    */
/* VERSION:   1.0                                                         */
/* CHANGELOG:                                                             */
/*------------------------------------------------------------------------*/        

/*------------------------------------------------------------------------*/                                                       
/* INSTALL:   1) Application requires Teradata S3 connector               */
/*            2) Copy the folder tpt-s3-hive to your Linux home directory */
/*            3) Set your Teradata logon credentials and TPT operator     */
/*               attributes, output dir path in the param/vTpt files      */
/*            4) Set your database, object names, date parameters in  the */
/*               parameter files eg. param/ref (reference data tables)    */
/*            5) Execute ./load.sh to run application                     */
/*------------------------------------------------------------------------*/
