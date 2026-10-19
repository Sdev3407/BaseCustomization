pageextension 50254 "FinishedProductionOrders_Ext" extends "Finished Production Orders"
{
    layout { }
    actions
    {
        addbefore("&Warehouse Entries")
        {
            action(ReopenFinishedProdOrder)
            {
                ApplicationArea = Manufacturing;
                Caption = 'Reopen';
                Image = ReOpen;
                ToolTip = 'Reopen the production order to change it after it has been finished.';

                trigger OnAction()
                var
                    ProdOrderStatusManagement: Codeunit BaseModificationCodeunitt;
                begin
                    ProdOrderStatusManagement.ReopenFinishedProdOrder(Rec);
                end;
            }
            action(API_test)
            {
                ApplicationArea = All;
                Caption = 'API Test';
                Image = Information;
                ToolTip = 'Test API.';

                //     trigger OnAction()
                //     var
                //         BaseCodeunit: Codeunit "API Functions";
                //         DGLE: Record "Detailed GST Ledger Entry";
                //     begin
                //         DGLE.Reset();
                //         DGLE.SetRange("Posting Date", 20260701D, 20260731D);
                //         DGLE.SetRange("Source Type", DGLE."Source Type"::" ");
                //         DGLE.SetRange("Transaction Type", DGLE."Transaction Type"::Sales);
                //         DGLE.SetRange("Document No.", '');
                //         if DGLE.FindSet() then
                //             repeat
                //                 Message('%1', BaseCodeunit.RemoveDuplicateGSTLedgerEntries(DGLE."Document No.", false));

                //             until DGLE.Next() = 0;
                //     end;
                // }

                trigger OnAction()
                var
                    BaseCodeunit: Codeunit "API Functions";
                    DGLE: Record "Detailed GST Ledger Entry";
                    LastDocumentNo: Code[20];
                    TotalDeleted: Integer;
                    DocsProcessedCount: Integer;
                begin
                    DGLE.Reset();
                    DGLE.SetCurrentKey("Document No.", "Posting Date");
                    DGLE.SetRange("Posting Date", 20260801D, 20260810D);
                    DGLE.SetRange("Source Type", DGLE."Source Type"::" ");
                    DGLE.SetRange("Transaction Type", DGLE."Transaction Type"::Sales);
                    // DGLE.SetFilter("Document No.", '%1|%2', 'TS10122627002781','TS10042627000297'); // Exclude empty document numbers
                    if DGLE.FindSet() then
                        repeat
                            // Pass each Document No. ONLY ONCE when encountered for the first time
                            if DGLE."Document No." <> LastDocumentNo then begin
                                LastDocumentNo := DGLE."Document No.";

                                // Call function per Document No.
                                TotalDeleted += BaseCodeunit.RemoveDuplicateGSTLedgerEntries(DGLE."Document No.", false);
                                DocsProcessedCount += 1;
                            end;
                        until DGLE.Next() = 0;


                end;
            }
        }
    }
}