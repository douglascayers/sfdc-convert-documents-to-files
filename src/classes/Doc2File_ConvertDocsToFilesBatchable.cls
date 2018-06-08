/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public without sharing class Doc2File_ConvertDocsToFilesBatchable implements Database.Batchable<SObject> {

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.start: ' + context );

        return Database.getQueryLocator([
            SELECT
                Id,
                Name,
                DeveloperName,
                Description,
                ContentType,
                Type,
                Body,
                Url,
                Keywords,
                FolderId,
                Folder.Name,
                Folder.DeveloperName,
                AuthorId,
                CreatedById,
                CreatedDate,
                LastModifiedById,
                LastModifiedDate
            FROM
                Document
            WHERE
                Type = 'URL'
                OR
                BodyLength > 0
            ORDER BY
                FolderId,
                Id
        ]);
    }

    public void execute( Database.BatchableContext context, List<Document> documents ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.execute: ' + context );

        SavePoint sp = Database.setSavepoint();

        try {

            Doc2File_FolderConversionService service = new Doc2File_FolderConversionService();

            service.convertDocumentsToFiles( documents );

        } catch ( Exception e ) {

            Database.rollback( sp );

            System.debug( LoggingLevel.ERROR, e );

            // todo create doc2file_log__c

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.finish: ' + context );

        // todo send email to user that conversion job finished

    }

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