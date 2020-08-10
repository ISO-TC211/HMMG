option explicit

!INC Local Scripts.EAConstants-VBScript

'
' Script Name: CHG Move elements between packages
' Author: Knut Jetlund	
' Purpose: Move elements from one package to another, e.g., replace elments in main package with elements from amendment
' Date: 20200805
'

'ISO DAMD 19115-1 Edition 1 (Amendment 1): 
'const sourcePackageGUID = "{E01F8948-760C-4724-80C4-EE201B9DE4A1}"
'ISO DAMD 19115-1 Edition 1 (Amendment 2): 
const sourcePackageGUID = "{9D7C5D0A-1142-46bc-91C3-FA2B6D31C59A}"

'ISO 19115-1 Edition 1 (Complete):
const targetPackageGUID = "{487216E5-A26A-4a5b-B4A1-E60590EAE13D}"

dim sourcePackage as EA.Package
dim targetPackage as EA.Package

dim subSP as EA.Package
dim subTP as EA.Package

dim sEl as EA.Element
dim tEl as EA.Element
dim el as EA.Element
dim attr as EA.Attribute

dim sDiagram as EA.Diagram
dim tDiagram as EA.Diagram

dim dObject as EA.DiagramObject

dim i,j

'Recursive loop through subpackages, and do the thing
sub recPros(pck)
	Repository.WriteOutput "Script", Now & " Checking diagrams and attributes in package: " & pck.Name, 0
	
	'Replace diagram object references	
	for each tDiagram in pck.Diagrams
		'Repository.WriteOutput "Script", Now & " Checking diagram: " & tDiagram.Name, 0	
		'find any diagramobject representing target element
		for each dObject in tDiagram.DiagramObjects
			if dObject.ElementID = tEl.ElementID then
				'Replace with source element
				Repository.WriteOutput "Script", Now & " Replacing element in diagram: " & tDiagram.Name, 0	
				dObject.ElementID = sEl.ElementID
				dObject.Update
			end if
		next	
	next

	'Replace attribute type references
	for each el in pck.Elements
		for each attr in el.Attributes
			if attr.ClassifierID = tEl.ElementID then
				'Replace with source element
				Repository.WriteOutput "Script", Now & " Replacing element reference for attribute: " & el.Name & "." & attr.Name, 0	
				attr.ClassifierID = sEl.ElementID
				attr.Update
			end if
		next
	next
	
	dim subP as EA.Package
	for each subP in pck.packages
	    recPros(subP)
	next
end sub


sub main

	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	set sourcePackage = Repository.GetPackageByGuid(sourcePackageGUID)
	Repository.WriteOutput "Script", Now & " Source package: " & sourcePackage.Name, 0

	set targetPackage = Repository.GetPackageByGuid(targetPackageGUID)
	Repository.WriteOutput "Script", Now & " Target package: " & targetPackage.Name, 0

	For each subSP in sourcePackage.Packages
		Repository.WriteOutput "Script", Now & " ------------------- " , 0	
		Repository.WriteOutput "Script", Now & " Source sub package: " & subSP.Name, 0	
		Repository.WriteOutput "Script", Now & " ------------------- " , 0	
		
		'Find target sub package
		dim sTP as EA.Package
		set subTP = nothing
		for each sTP in targetPackage.Packages
			if sTP.Name = subSP.Name then set subTP = sTP
		next
		
		if not subTP is nothing then
			Repository.WriteOutput "Script", Now & " Target sub package: " & subTP.Name, 0	
			for each sEl in subSP.Elements
				Repository.WriteOutput "Script", Now & " --------------- " , 0	
				Repository.WriteOutput "Script", Now & " Source element: " & sEl.Name, 0	
				
				'Find target element in target sub package
				set el = nothing
				for each el in subTP.Elements
					if el.Name = sEl.Name then set tEl = el
				next
				
				'Elements from the new complete package are not references as attribute types in other standards, 
				'as it is a clone with new GUIDs. External packages refer to the official packages. 
				'Therefore, elements in the complete package (target) can be replaced with elements from the amedment package (source).
				'But all internal references in attribute types and diagram objects must be replaced with the new element id
				'all internal associations are considered already duplicated to the new element, as it was established as a copy of the old element
				
				if not tEl is nothing then
					Repository.WriteOutput "Script", Now & " Target element: " & tEl.Name, 0	
					
					'Recursive processes for diagram objects and attributes in main target package and all sub packages:
					recPros(targetPackage)	
					
					'Delete target element
					for i = 0 to subTP.Elements.Count - 1
						set el = subTP.Elements.GetAt(i)
						if el.ElementID= tEl.ElementID then 
							'Repository.WriteOutput "Script", Now & " Deleting target element", 0	
							subTP.Elements.DeleteAt i, false
						end if
					next	
					'Move source element to target sub package
					Repository.WriteOutput "Script", Now & " Moving source element to target sub package", 0	
					sEl.PackageID = subTP.PackageID
					sEl.Update
					subTP.Elements.Refresh
				end if		
			next
			
			'diagrams: the source diagram shall replace the old target diagram 
			for each sDiagram in subSP.Diagrams
				Repository.WriteOutput "Script", Now & " Source diagram: " & sDiagram.Name, 0	
				
				'find target diagram
				dim tDgr as EA.Diagram
				for i = 0 to subTP.Diagrams.Count - 1
					set tDiagram = subTP.Diagrams.GetAt(i)
					if tDiagram.Name = sDiagram.Name then 
						Repository.WriteOutput "Script", Now & " Target diagram: " & tDiagram.Name, 0	
						Repository.WriteOutput "Script", Now & " Deleting old target diagram", 0	
						subTP.Diagrams.DeleteAt i, false
					end if	
				next
				'move source diagram to target sub package
				Repository.WriteOutput "Script", Now & " Moving source diagram to target sub package: " & sDiagram.Name, 0	
				sDiagram.PackageID = subTP.PackageID
				sDiagram.Update
				subTP.Diagrams.Refresh
			next
		else
			'clone complete package
		end if	
	Next
	
	Repository.WriteOutput "Script", Now & " Finished, check the Error and Types tabs", 0 

end sub

main