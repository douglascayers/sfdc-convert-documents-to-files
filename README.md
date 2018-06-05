Convert Documents to Salesforce Files
=======================================

Overview
--------

Coming soon!

In the meantime, check out my other conversion to files projects:
  * [Convert Attachments to Files](https://github.com/douglascayers/sfdc-convert-attachments-to-chatter-files)
  * [Convert Google Docs to Files](https://douglascayers.com/2017/10/19/convert-googledoc-records-to-salesforce-files/)
  * [Convert Notes to Enhanced Notes](https://github.com/douglascayers/sfdc-convert-notes-to-chatter-notes)

--- 


Notes to myself during development
----------------------------------

The conversion process starts in [Doc2File_PrepareFoldersBatchable.cls](https://github.com/douglascayers/sfdc-convert-documents-to-files/blob/master/src/classes/Doc2File_PrepareFoldersBatchable.cls).
From there, just follow the code ;)

things to put in the wiki...

Salesforce does not (yet?) provide an automated way to [migrate Documents to Files](https://help.salesforce.com/articleView?id=docs_documents_to_files.htm&type=5).
The purpose of this open source project is to provide the community an option for automating the conversion.

Be aware of content limits:
* https://help.salesforce.com/articleView?id=content_file_size_limits.htm&type=5
* Max 2,000 libraries (take number of current libraries plus document folders must be <= 2,000)
* Max 200,000 files can be created per 24/hour (less in dev orgs and sandboxes)
    * plan your migration accordingly as salesforce gives no programmatic way to know how close to the limit you are :(
    * if you blow through the 24/hour limit, you may have to contact Salesforce Support to increase it or users won't be able create/upload files for a while
* this tool does not delete the original documents and folders because to do so requires to delete and purge the documents from your org's recycle bin. Making data irrecoverable is not the business I want to be in.
    
Post-conversion, for any documents that were marked as externally available, then need to [enable public link sharing](https://help.salesforce.com/articleView?id=collab_files_sharing_via_link.htm&type=5) on the converted files.

Since Documents are not supported in Lightning Experience, you will want to initiate the conversion process from Classic.
[How to Switch from Lightning Experience to Classic](https://help.salesforce.com/articleView?id=000230642&type=1)
If you cannot switch to Classic, make sure this feature has not been hidden from your user.
[Hide Option to Switch to Salesforce Classic](https://releasenotes.docs.salesforce.com/en-us/summer17/release-notes/rn_general_lex_hide_switcher.htm)

Documents whose file size is 0 bytes are not converted, unless their type is URL (aka, bookmarks).

---

Documentation and Discussion
--------------------------

* Read the [wiki page](https://github.com/douglascayers/sfdc-convert-documents-to-files/wiki) for further documentation on Convert Documents to Files app.
* Read the [FAQ page](https://github.com/douglascayers/sfdc-convert-documents-to-files/wiki/Frequently-Asked-Questions) to help troubleshoot technical issues.
* Raise well defined issues and ideas via the [Issues feature](https://github.com/douglascayers/sfdc-convert-documents-to-files/issues).


Pre-Requisites
--------------
1. Enable [Create Audit Fields](https://help.salesforce.com/articleView?id=000213290&type=1&language=en_US) so Document create/update/owner fields can be preserved on the new files.
2. As the admin performing the conversion, your user record needs **Salesforce CRM Content User** enabled. 
3. Read the [instructions in the wiki](https://github.com/douglascayers/sfdc-convert-documents-to-files/wiki/Pre-Requisites-Instructions) for screen shots and step-by-steps.


Packaged Release History
========================

Support
-------

Documents to Files Converter is an open source project. It's an independent project with its ongoing development happening in the evenings and weekends.
Maintaining and developing new features takes a considerable amount of time. If your business has found value in my projects, please consider [showing
your support](https://douglascayers.com/thanks-for-your-support/) by contributing to my [virtual tip jar on PayPal](https://www.paypal.me/douglascayers/). Thank you! ❤️

Release 1.0 (current)
-----------
* In Development

---

Installing the Source Code (Developers)
---------------------------------------

You may install the unmanaged code from GitHub and make any desired adjustments.
You are responsible for ensuring unit tests meet your org's validation rules and other requirements.
You can conveniently deploy the source to a new scratch org using [Andy Fawcett](https://andyinthecloud.com/category/githubsfdeploy/)'s deploy tool:

[![Deploy from GitHub](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com?owner=douglascayers&repo=convert-documents-to-files)


Credits
=======

[Doug Ayers](https://douglascayers.com) develops and maintains the project.

[FinancialForce Apex Metadata API Wrapper](https://github.com/financialforcedev/apex-mdapi) for developing tools for querying Salesforce Metadata API.

[Cari Aves](https://success.salesforce.com/ProfileView?u=00530000008A7mvAAC), Salesforce Product Manager, for providing encouragement and use cases.

[Neil Hayek](https://success.salesforce.com/ProfileView?userId=00530000003SpRm), Salesforce Files Expert, for providing solution design and guidance.


License
=======

The source code is licensed under the [BSD 3-Clause License](LICENSE)