Convert Documents to Salesforce Files
=======================================

Overview
--------

coming soon...

post-conversion, for any documents that were marked as externally available, then need to [enable public link sharing](https://help.salesforce.com/articleView?id=collab_files_sharing_via_link.htm&type=5) on the converted files.

Since Documents are not supported in Lightning Experience, you will want to initiate the conversion process from Classic.
[How to Switch from Lightning Experience to Classic](https://help.salesforce.com/articleView?id=000230642&type=1)
If you cannot switch to Classic, make sure this feature has not been hidden from your user.
[Hide Option to Switch to Salesforce Classic](https://releasenotes.docs.salesforce.com/en-us/summer17/release-notes/rn_general_lex_hide_switcher.htm)


Documentation and Discussion
--------------------------

* Read the [wiki page](https://github.com/douglascayers/sfdx-convert-documents-to-files/wiki) for further documentation on Convert Documents to Files app.
* Read the [FAQ page](https://github.com/douglascayers/sfdx-convert-documents-to-files/wiki/Frequently-Asked-Questions) to help troubleshoot technical issues.
* Raise well defined issues and ideas via the [Issues feature](https://github.com/douglascayers/sfdx-convert-documents-to-files/issues).


Pre-Requisites
--------------
1. Enable [Create Audit Fields](https://help.salesforce.com/articleView?id=000213290&type=1&language=en_US) so Document create/update/owner fields can be preserved on the new files.
2. As the admin performing the conversion, your user record needs **Salesforce CRM Content User** enabled. 
3. You will need to configure a **Named Credential** because the app processes records in background jobs and will need to securely invoke the Salesforce REST API via OAuth when you are not around. 

Please see the [instructions in the wiki](https://github.com/douglascayers/sfdx-convert-documents-to-files/wiki/Pre-Requisites-Instructions) for screen shots and step-by-steps.


Packaged Release History
========================

Support
-------

Mass Action Scheduler is an open source project. It's an independent project with its ongoing development happening in the evenings and weekends.
Maintaining and developing new features takes a considerable amount of time. If your business has found value in my projects, please consider [showing
your support](https://douglascayers.com/thanks-for-your-support/) by contributing to my [virtual tip jar on PayPal](https://www.paypal.me/douglascayers/). Thank you! ❤️

Release 1.0 (current)
-----------
* Install Package ([Production]()) ([Sandbox]())
* Initial managed package offering

---

Installing the Source Code (Developers)
---------------------------------------

This repository is organized using [Salesforce DX](https://trailhead.salesforce.com/en/trails/sfdx_get_started).
You may install the unmanaged code from GitHub and make any desired adjustments.
You are responsible for ensuring unit tests meet your org's validation rules and other requirements.
You can conveniently deploy the source to a new scratch org using [Wade Wegner](https://github.com/wadewegner/deploy-to-sfdx)'s deploy tool:

[![Deploy from GitHub](https://deploy-to-sfdx.com/dist/assets/images/DeployToSFDX.svg)](https://deploy-to-sfdx.com?template=https://github.com/douglascayers/sfdx-convert-documents-to-files)


Credits
=======

[Doug Ayers](https://douglascayers.com) develops and maintains the project.

[FinancialForce Apex Metadata API Wrapper](https://github.com/financialforcedev/apex-mdapi) for developing tools for querying Salesforce Metadata API.

[Cari Aves](https://success.salesforce.com/ProfileView?u=00530000008A7mvAAC), Salesforce Product Manager, for providing encouragement and use cases.

[Neil Hayek](https://success.salesforce.com/ProfileView?userId=00530000003SpRm), Salesforce Files Expert, for providing solution design and guidance.


License
=======

The source code is licensed under the [BSD 3-Clause License](LICENSE)