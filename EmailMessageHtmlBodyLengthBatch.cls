/**
 * @description Batch Apex to backfill EmailMessage.HTMLBody_Length__c with the length of HTMLBody.
 *
 * Behavior:
 * - Queries EmailMessage records where HTMLBody_Length__c is null or out of sync (optional flag).
 * - Computes length as 0 when HtmlBody is null.
 * - Updates in batches with Database.update in USER_MODE and with partial success handling.
 *
 * Usage:
 *   Database.executeBatch(new EmailMessageHtmlBodyLengthBatch(), 200);
 *
 * Notes:
 * - This batch runs in system context by default but updates are performed in USER_MODE per record-level access best practices.
 * - Ensure the custom field EmailMessage.HTMLBody_Length__c exists before running.
 */
public without sharing class EmailMessageHtmlBodyLengthBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final Boolean resyncAll;

    /**
     * @param resyncAll If true, recompute for all EmailMessage records; if false, only where HTMLBody_Length__c is null.
     */
    public EmailMessageHtmlBodyLengthBatch(Boolean resyncAllSetting) {
        this.resyncAll = resyncAllSetting == null ? false : resyncAllSetting;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Select minimum fields. Filter to null or resync-all.
        String baseQuery = 'SELECT Id, HtmlBody, HTMLBody_Length__c FROM EmailMessage';
        String whereClause = resyncAll
            ? ''
            : ' WHERE HTMLBody_Length__c = NULL';
        return Database.getQueryLocator(baseQuery + whereClause);
    }

    public void execute(Database.BatchableContext bc, List<EmailMessage> scope) {
        if (scope == null || scope.isEmpty()) return;

        // Prepare updates
        List<EmailMessage> toUpdate = new List<EmailMessage>();
        toUpdate.ensureCapacity(scope.size());

        for (EmailMessage em : scope) {
            Integer computed = (em.HtmlBody == null) ? 0 : em.HtmlBody.length();
            // If resyncAll, always set. Otherwise set only when currently null.
            if (resyncAll || em.HTMLBody_Length__c == null || em.HTMLBody_Length__c != computed) {
                EmailMessage upd = new EmailMessage(
                    Id = em.Id,
                    HTMLBody_Length__c = computed
                );
                toUpdate.add(upd);
            }
        }

        if (!toUpdate.isEmpty()) {
            // Update in user mode, allow partial success
            Database.SaveResult[] results = Database.update(toUpdate, false, AccessLevel.USER_MODE);
            // Optionally collect failures (stateful)
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    for (Database.Error e : results[i].getErrors()) {
                        // Avoid System.debug in production; consider a custom logging framework if needed.
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optionally notify or log results.
    }
}
