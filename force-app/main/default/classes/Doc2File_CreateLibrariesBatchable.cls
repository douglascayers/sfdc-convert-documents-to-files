/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdx-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public without sharing class Doc2File_CreateLibrariesBatchable implements Database.Batchable<Convert_Document_Folder_to_Library__c> {

    public List<Convert_Document_Folder_to_Library__c> start( Database.BatchableContext context ) {
        return [
            SELECT
                Id
            FROM
                Convert_Document_Folder_to_Library__c
            WHERE
                Library_ID__c = null
        ];
    }

    public void execute( Database.BatchableContext context, List<Convert_Document_Folder_to_Library__c> records ) {

    }

    public void finish( Database.BatchableContext context ) {

    }

        /*
            // ContentWorkspaceMember.MemberId must be a User ID or Public Group ID,
            // but the Group IDs derived from Document Folder shares could be roles, role and subordinates, etc.
            // So to ensure the new library has same membership as the document folder it is based on,
            // then we must create a public group whose members are the same as the document folder's shares.
            // Then we can add this new public group as the new library's membership.

            // These are all system objects and their DML can occur in the same transaction.
            // Creating and adding files to the library must occur in a separate batch job.

            Group g = new Group(
                Name = 'MyWorkspaceGroup',
                DeveloperName = 'MyWorkspaceGroup',
                Type = 'Regular'
            );
            insert g;

            GroupMember gm = new GroupMember(
                GroupId = g.Id,
                UserOrGroupId = '00GL0000001puw4MAA'
            );
            insert gm;

            ContentWorkspace w = new ContentWorkspace(
                Name = 'MyWorkspace',
                DeveloperName = 'MyWorkspace',
                ShouldAddCreatorMembership = true
            );
            insert w;

            ContentWorkspaceMember wm = new ContentWorkspaceMember(
                ContentWorkspaceId = w.Id,
                ContentWorkspacePermissionId = '05PL00000008SF3MAM',
                MemberId = g.Id
            );
            insert wm;
         */

}
/*
BSD 3-Clause License

Copyright (c) 2018, Doug Ayers, douglascayers.com
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/