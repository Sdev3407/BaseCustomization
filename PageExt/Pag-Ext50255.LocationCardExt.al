pageextension 50255 "LocationCard_Ext" extends "Location Card"
{
    layout { }
    actions
    {
        addafter("Online Map")
        {
            action("UpdateInvtSetup")
            {
                ApplicationArea = all;
                Caption = 'Update Inventory Posting';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;

                trigger OnAction()
                var
                    Co: Codeunit BaseModificationCodeunitt;
                begin
                    CompanyInfo.Get;
                    Rec.TestField("Shortcut Dimension 1 Code");
                    Rec.TestField("Shortcut Dimension 2 Code");
                    Rec.TestField("Responsibility Center");
                    if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then
                        Co.CreateInventoryPostingSetups(Rec);
                    if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] then
                        Co.CreateInventoryPostingSetupsForStarFoods(Rec);
                end;
            }

        }

    }
    trigger OnAfterGetCurrRecord()
    begin
        //   CurrPage.IncomingDocAttachFactBox.PAGE.LoadDataFromRecord(Rec);


    end;


    var
        CompanyInfo: Record "Company Information";

}