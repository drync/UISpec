
#import "UIQueryPickerView.h"


@implementation UIQueryPickerView

-(UIQuery *)selectByIndex: (int)rowIndex
{
	UIPickerView* picker =(UIPickerView*) self;
	[picker selectRow:rowIndex inComponent:0 animated:YES];
	[picker.delegate pickerView: picker didSelectRow:rowIndex inComponent:0 ];
	return self;
}
	
-(UIQuery *)selectByText: (NSString*) iText
{
	UIPickerView* picker =(UIPickerView*) self;
	for(int iii=0; iii < [picker numberOfRowsInComponent: 0]; iii++)
	{
		NSString* text = [picker.delegate pickerView:picker titleForRow:iii forComponent:0];
		if([text isEqualToString:iText])
		{
			[self selectByIndex: iii];
			return self;
		}
	}
	[NSException raise:@"UIQueryPickerView: Can't Find Value" format:@"Text '%@' not found in pickerView",iText];
	return self;
}

@end
