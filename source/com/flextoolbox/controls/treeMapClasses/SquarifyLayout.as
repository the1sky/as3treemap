////////////////////////////////////////////////////////////////////////////////
//
//  Copyright (c) 2008 Josh Tynjala
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to 
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

package com.flextoolbox.controls.treeMapClasses
{
	import flash.geom.Rectangle;

	/**
	 * The squarify treemap layout algorithm creates nodes that are unordered,
	 * with the lowest possible aspect ratios, and medium stability of node
	 * positions. In short, the algorithm attempts to make all the nodes into
	 * squares.
	 *  
	 * @see com.flextoolbox.controls.TreeMap
	 * @author Josh Tynjala
	 */
	public class SquarifyLayout implements ITreeMapLayoutStrategy
	{
		
	//--------------------------------------
	//  Constructor
	//--------------------------------------
	
		/**
		 * Constructor.
		 */
		public function SquarifyLayout()
		{
		}
		
	//--------------------------------------
	//  Properties
	//--------------------------------------
	
		/**
		 * @private
		 * The sum of the weight values for the remaining items that have not
		 * yet been positioned and sized.
		 */
		private var _totalRemainingWeightSum:Number = 0;

	//--------------------------------------
	//  Public Methods
	//--------------------------------------
	
		/**
		 * @inheritDoc
		 */
		public function updateLayout(branchRenderer:ITreeMapBranchRenderer, bounds:Rectangle):void
		{
			var items:Array = branchRenderer.itemsToArray();
			this.squarify(items, bounds.clone());
		}
		
	//--------------------------------------
	//  Private Methods
	//--------------------------------------
		
		/**
		 * @private
		 * The main squarify algorithm.
		 */
		private function squarify(items:Array, bounds:Rectangle):void
		{
			items = items.sort(compareWeights, Array.DESCENDING);
			this._totalRemainingWeightSum = this.sumWeights(items);
			var lastAspectRatio:Number = Number.MAX_VALUE;
			var lengthOfShorterEdge:Number = Math.min(bounds.width, bounds.height);
			var row:Array = [];
			do
			{
				var nextItem:TreeMapItemLayoutData = TreeMapItemLayoutData(items.shift());
				row.push(nextItem);
				var drawRow:Boolean = true;
				var aspectRatio:Number = this.calculateWorstAspectRatioInRow(row, lengthOfShorterEdge, bounds);
				if(lastAspectRatio >= aspectRatio)
				{
					lastAspectRatio = aspectRatio;
					
					//if this is the last item, force the row to draw
					drawRow = items.length == 0;
				}
				else
				{
					//put the item back if the aspect ratio is worse than the previous one
					//we want to draw, of course
					items.unshift(row.pop());
				}
				
				if(drawRow)
				{
					bounds = this.layoutRow(row, lengthOfShorterEdge, bounds);
					
					//reset for the next pass
					lastAspectRatio = Number.MAX_VALUE;
					lengthOfShorterEdge = Math.min(bounds.width, bounds.height);
					row = [];
				}
			}
			while(items.length > 0);
		}
		
		/**
		 * @private
		 * Compares the weight values of TreeMapItemLayoutData instances.
		 */
		private function compareWeights(a:TreeMapItemLayoutData, b:TreeMapItemLayoutData):int
		{
			//first check for nulls
			if(a == null && b == null)
			{
				return 0;
			}
			if(a == null)
			{
				return 1;
			}
			if(b == null)
			{
				return -1;
			}
                 
			var weightA:Number = a.weight;
			var weightB:Number = b.weight;

			if(weightA < weightB) return -1;
			if(weightA > weightB) return 1;
			return 0;
		}
		
		/**
		 * @private
		 * Determines the worst (maximum) aspect ratio of the items in a row.
		 * 
		 * @param row						a row of items for which to calculate the worst aspect ratio
		 * @param lengthOfShorterEdge		the length, in pixels, of the edge of the remaining bounds on which to draw the row (the shorter one)
		 * @return							the worst aspect ratio for the items in the row
		 */
		private function calculateWorstAspectRatioInRow(row:Array, lengthOfShorterEdge:Number, bounds:Rectangle):Number
		{
			if(row.length == 0 || lengthOfShorterEdge <= 0)
			{
				throw new ArgumentError("Row must contain at least one item, and the length of the row must be greater than zero.");
			}
			
			var totalArea:Number = bounds.width * bounds.height;
			
			var maxArea:Number = Number.MIN_VALUE;
			var minArea:Number = Number.MAX_VALUE;
			var sumOfAreas:Number = 0;
			for each(var data:TreeMapItemLayoutData in row)
			{
				var area:Number = totalArea * (data.weight / this._totalRemainingWeightSum);
				minArea = Math.min(area, minArea);
				maxArea = Math.max(area, maxArea);
				sumOfAreas += area;
			}
			
			// max(w^2 * r+ / s^2, s^2 / (w^2 / r-))
			var sumSquared:Number = sumOfAreas * sumOfAreas;
			var lengthSquared:Number = lengthOfShorterEdge * lengthOfShorterEdge;
			return Math.max(lengthSquared * maxArea / sumSquared, sumSquared / (lengthSquared * minArea));
		}
		
		/**
		 * @private
		 * Draws a row of items
		 * 
		 * @param row						The items in the row
		 * @param lengthOfShorterEdge		the length, in pixels, of the edge of the remaining bounds on which to draw the row (the shorter one)
		 * @param bounds					The remaining bounds into which to draw items
		 */
		private function layoutRow(row:Array, lengthOfShorterEdge:Number, bounds:Rectangle):Rectangle
		{
			var horizontal:Boolean = lengthOfShorterEdge == bounds.width;
			var lengthOfLongerEdge:Number = horizontal ? bounds.height : bounds.width;
			var sumOfRowWeights:Number = this.sumWeights(row);
			
			var lengthOfCommonItemEdge:Number = lengthOfLongerEdge * (sumOfRowWeights / this._totalRemainingWeightSum);
			if(isNaN(lengthOfCommonItemEdge))
			{
				lengthOfCommonItemEdge = 0;
			}
			
			var rowCount:int = row.length;
			var position:Number = 0;
			for(var i:int = 0; i < rowCount; i++)
			{
				var item:TreeMapItemLayoutData = TreeMapItemLayoutData(row[i]);
				var weight:Number = item.weight;
				
				var ratio:Number = weight / sumOfRowWeights;
				//if all nodes in a row have a weight of zero, give them the same area
				if(isNaN(ratio))
				{
					if(sumOfRowWeights == 0 || isNaN(sumOfRowWeights))
					{
						ratio = 1 / row.length;
					}
					else
					{
						ratio = 0;
					}
				}
				
				var lengthOfItemEdge:Number = lengthOfShorterEdge * ratio;
				
				if(horizontal)
				{
					item.x = bounds.x + position;
					item.y = bounds.y;
					item.width = lengthOfItemEdge;
					item.height = lengthOfCommonItemEdge;
				}
				else
				{
					item.x = bounds.x;
					item.y = bounds.y + position;
					item.width = Math.max(0, lengthOfCommonItemEdge);
					item.height = Math.max(0, lengthOfItemEdge);
				}
				position += lengthOfItemEdge;
			}
			
			this._totalRemainingWeightSum -= sumOfRowWeights;
			return this.updateBoundsForNextRow(bounds, lengthOfCommonItemEdge);
		}
		
		/**
		 * @private
		 * After a row is drawn, the bounds must be made smaller to draw the
		 * next row.
		 */
		private function updateBoundsForNextRow(bounds:Rectangle, modifier:Number):Rectangle
		{
			if(bounds.width > bounds.height)
			{
				var newWidth:Number = Math.max(0, bounds.width - modifier);
				bounds.x -= (newWidth - bounds.width);
				bounds.width = newWidth;
			}
			else
			{
				var newHeight:Number = Math.max(0, bounds.height - modifier);
				bounds.y -= (newHeight - bounds.height);
				bounds.height = newHeight;
			}
			
			return bounds;
		}
	
		/**
		 * @private
		 * Calculates the sum of weight values in an Array of
		 * TreeMapItemLayoutData instances.
		 */
		private function sumWeights(source:Array):Number
		{
			var sum:Number = 0;
			for each(var item:TreeMapItemLayoutData in source)
			{
				sum += item.weight;
			}
			return sum;
		}
		
	}
}