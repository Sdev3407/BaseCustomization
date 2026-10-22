pageextension 50256 "VendorCard_Ex" extends "Vendor Card"
{
    layout
    {
        modify("P.A.N. No.")
        {
            trigger OnAfterValidate()
            var

                UpdatePANDetailsFromPortal: Codeunit BaseModificationCodeunitt;
                P: Page "Vendor Card";
            begin
                CompanyInfo.Get;
                if (Rec."P.A.N. No." <> '') and (rec."P.A.N. Status" = rec."P.A.N. Status"::" ") then begin
                    if not CompanyInfo."Disable PAN Varification API" then
                        UpdatePANDetailsFromPortal.VerifyPANDetails(rec."No.", (CopyStr(Rec."P.A.N. No.", StrLen(Rec."P.A.N. No.") - 3, 4)) + Format(Random(99999)), Rec."P.A.N. No.", rec."API PAN Type", rec."API Full Name", rec."API DOB", rec."API aadhaar Seeding Status")
                end else begin
                    rec."API PAN Type" := '';
                    rec."API Full Name" := '';
                    rec."API DOB" := '';
                    rec."API aadhaar Seeding Status" := '';
                end;
            end;
        }
    }
    actions
    {
        addlast(Documents)
        {

            action("PAN Varify")
            {
                ApplicationArea = all;
                Promoted = true;
                trigger OnAction()
                var
                    UpdatePANDetailsFromPortal: Codeunit BaseModificationCodeunitt;
                begin
                    if (Rec."P.A.N. No." <> '') and (rec."P.A.N. Status" = rec."P.A.N. Status"::" ") then
                        UpdatePANDetailsFromPortal.VerifyPANDetails(rec."No.", (CopyStr(Rec."P.A.N. No.", StrLen(Rec."P.A.N. No.") - 3, 4)) + Format(Random(99999)), Rec."P.A.N. No.", rec."API PAN Type", rec."API Full Name", rec."API DOB", rec."API aadhaar Seeding Status");
                end;
            }
        }
    }


    trigger OnAfterGetCurrRecord()
    begin
        OpenApprovalEntriesExist := ApprovalsMgmt.HasOpenApprovalEntries(Rec.RecordId);

    end;

    var
        CompanyInfo: Record "Company Information";
        OpenApprovalEntriesExist: Boolean;
        ApprovalsMgmt: Codeunit "Approvals Mgmt.";
}