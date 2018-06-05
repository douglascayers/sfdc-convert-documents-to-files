/**
 * Author: Doug Ayers
 * Website: https://douglascayers.com
 * GitHub: https://github.com/douglascayers/sfdc-convert-documents-to-files
 * License: BSD 3-Clause License
 */
public class Doc2File_ConvertDocsToFilesBatchable implements Database.Batchable<Document> {

    public List<Document> start( Database.BatchableContext context ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.start: ' + context );

        return [
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
        ];
    }

    public void execute( Database.BatchableContext context, List<Document> documents ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.execute: ' + context );

        Doc2File_FolderConversionService service = new Doc2File_FolderConversionService();

        service.convertDocumentsToFiles( documents );

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'Doc2File_ConvertDocsToFilesBatchable.finish: ' + context );

        // todo send email to user that conversion job finished

    }

}