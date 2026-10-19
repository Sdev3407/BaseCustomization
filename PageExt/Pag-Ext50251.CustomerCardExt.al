pageextension 50251 "CustomerCard_Ext" extends "Customer Card"
{
    layout
    {
        modify("P.A.N. No.")
        {
            Editable = PageEditable;
            trigger OnAfterValidate()
            var

                UpdatePANDetailsFromPortal: Codeunit BaseModificationCodeunitt;

            begin
                if (Rec."P.A.N. No." <> '') and (rec."P.A.N. Status" = rec."P.A.N. Status"::" ") then begin

                    UpdatePANDetailsFromPortal.VerifyPANDetails(rec."No.", (CopyStr(Rec."P.A.N. No.", StrLen(Rec."P.A.N. No.") - 3, 4)) + Format(Random(99999)), Rec."P.A.N. No.", rec."API pan_type", rec."API Full Name", rec."API DOB", rec."API aadhaar Seeding Status")
                end
                else begin
                    rec."API pan_type" := '';
                    rec."API Full Name" := '';
                    rec."API DOB" := '';
                    rec."API aadhaar Seeding Status" := '';
                end;
            end;
        }
    }
    actions
    {
        addafter("&Customer")
        {


            
            action("PAN Varify")
            {
                Promoted = true;
                ApplicationArea = All;

                trigger OnAction()
                var

                    UpdatePANDetailsFromPortal: Codeunit BaseModificationCodeunitt;

                begin
                    CompanyInfo.Get;
                    if (Rec."P.A.N. No." <> '') and (rec."P.A.N. Status" = rec."P.A.N. Status"::" ") then
                        if not CompanyInfo."Disable PAN Varification API" then
                            UpdatePANDetailsFromPortal.VerifyPANDetails(rec."No.", (CopyStr(Rec."P.A.N. No.", StrLen(Rec."P.A.N. No.") - 3, 4)) + Format(Random(99999)), Rec."P.A.N. No.", rec."API pan_type", rec."API Full Name", rec."API DOB", rec."API aadhaar Seeding Status");

                end;

            }

        }
    }

    trigger OnOpenPage()
    begin
        CompanyInfo.Get;
        UserSetup.Get(UserId);
        StarVisible := False;
        SFPLVisible := True;
        IF Rec.Status = Rec.Status::Open THEN begin
            // CurrPage.Editable(true);
            PageEditable := true;
        end ELSE
            //  CurrPage.Editable(false);
            PageEditable := false;

    end;

    trigger OnAfterGetCurrRecord()
    begin

        
    end;

    var
        CompanyInfo: Record "Company Information";
        StarVisible: Boolean;
        SFPLVisible: Boolean;
        PageEditable: Boolean;
        UserSetup: Record 91;
        OpenApprovalEntriesExist: Boolean;
        ApprovalsMgmt: Codeunit 1535;

}